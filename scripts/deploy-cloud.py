"""Deploy the hosted API and seed its first session. Credentials live in backend/.env."""
import asyncio
import json
import os
import secrets
import subprocess
from pathlib import Path

import httpx
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[1]
load_dotenv(ROOT / "backend/.env")
REF = os.environ["SUPABASE_PROJECT_REF"]
URL = os.environ["SUPABASE_URL"]
SEED = "50f71ba1-5c93-4de7-b043-cf2c215fa4c6"
MANAGEMENT = {"Authorization": "Bearer " + os.environ["SUPABASE_ACCESS_TOKEN"]}
DATA = {"apikey": os.environ["SUPABASE_SECRET_KEY"]}


def checked(response):
    if not response.is_success:
        text = response.text
        for name, value in os.environ.items():
            if any(word in name for word in ("TOKEN", "SECRET", "KEY")) and len(value) > 8:
                text = text.replace(value, "[redacted]")
        raise RuntimeError(f"Deployment request failed: {response.status_code}: {text[:500]}")
    return response


async def main():
    async with httpx.AsyncClient(timeout=180) as client:
        async def sql(query):
            return checked(await client.post(f"https://api.supabase.com/v1/projects/{REF}/database/query", headers=MANAGEMENT, json={"query": query})).json()

        await sql((ROOT / "supabase/migrations/202609230001_listening.sql").read_text())
        print("Database schema and access restrictions deployed.", flush=True)
        checked(await client.patch(f"https://api.supabase.com/v1/projects/{REF}/config/auth", headers=MANAGEMENT, json={"external_anonymous_users_enabled": True}))
        print("Automatic anonymous device sessions enabled.", flush=True)
        worker_secret = secrets.token_urlsafe(40)
        checked(await client.post(f"https://api.supabase.com/v1/projects/{REF}/secrets", headers=MANAGEMENT, json=[
            {"name": "AZURE_API_KEY", "value": os.environ["AZURE_API_KEY"]},
            {"name": "TCF_WORKER_SECRET", "value": worker_secret},
        ]))
        checked(await client.put(f"{URL}/storage/v1/bucket/tcf-listening-private", headers=DATA, json={"public": False, "file_size_limit": 30000000, "allowed_mime_types": ["audio/wav", "image/png", "image/jpeg", "application/json"]}))

        folder = ROOT / "backend/data" / SEED
        manifest = json.loads((folder / "content.json").read_text())
        plan = [q for batch in sorted(folder.glob("batch-*.json")) for q in json.loads(batch.read_text())["questions"]]
        assert len(plan) == 39
        assets = {}
        for question in manifest["questions"]:
            for asset in [question["audio"]] + ([question["image"]] if question["image"] else []):
                assets[asset["name"]] = {**asset, "path": f"{SEED}/{asset['name']}"}
                if asset["name"].endswith(".wav"):
                    assets[asset["name"]]["duration"] = question["duration"]
        limit = asyncio.Semaphore(4)

        async def upload(asset):
            async with limit:
                name = asset["name"]
                content_type = "audio/wav" if name.endswith(".wav") else "image/png"
                checked(await client.post(f"{URL}/storage/v1/object/tcf-listening-private/{asset['path']}", headers={**DATA, "Content-Type": content_type, "x-upsert": "true"}, content=(folder / name).read_bytes()))

        await asyncio.gather(*(upload(asset) for asset in assets.values()))
        row = {"id": SEED, "owner_id": None, "state": "ready", "phase": "Votre session est prête", "planned": 39, "images": 4, "audio": 39,
               "plan": plan, "assets": assets, "image_checks": {str(i): True for i in range(1, 5)}, "error": None, "lease_token": None, "lease_until": None}
        checked(await client.post(f"{URL}/rest/v1/tcf_listening_sessions?on_conflict=id", headers={**DATA, "Prefer": "resolution=merge-duplicates"}, json=row))
        print("39 audio files and 4 images uploaded; starter session ready.", flush=True)

        subprocess.run(["supabase", "functions", "deploy", "listening-api", "--project-ref", REF, "--no-verify-jwt", "--use-api"], cwd=ROOT, env=os.environ.copy(), check=True)
        await sql(f"""
create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;
do $$ declare secret_id uuid; begin
  select id into secret_id from vault.secrets where name='tcf_listening_worker_secret';
  if secret_id is null then
    perform vault.create_secret('{worker_secret}', 'tcf_listening_worker_secret');
  else
    perform vault.update_secret(secret_id, '{worker_secret}');
  end if;
end $$;
select cron.unschedule(jobid) from cron.job where jobname='tcf-listening-worker';
select cron.schedule('tcf-listening-worker', '* * * * *', $cron$
  select net.http_post(
    url := '{URL}/functions/v1/listening-api/internal/worker',
    headers := jsonb_build_object('Content-Type','application/json','x-worker-secret',
      (select decrypted_secret from vault.decrypted_secrets where name='tcf_listening_worker_secret')),
    body := '{{}}'::jsonb, timeout_milliseconds := 5000
  );
$cron$);
""")
        print("Durable background generation trigger configured.", flush=True)
        response = checked(await client.get(f"{URL}/functions/v1/listening-api/health"))
        assert response.json().get("seed_ready") is True
        print("Hosted API healthy; automatic first session is available.", flush=True)


if __name__ == "__main__":
    asyncio.run(main())
