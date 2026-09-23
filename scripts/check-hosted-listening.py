"""Live checks using the same public configuration as the iPhone, without Azure regeneration."""
import asyncio
import hashlib
import json
import os
import plistlib
import time
from pathlib import Path
from uuid import uuid4

import httpx
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[1]
load_dotenv(ROOT / "backend/.env")
config = plistlib.loads((ROOT / "apptsst/CloudConfiguration.plist").read_bytes())
project = config["projectURL"]
api = project + "/functions/v1/listening-api"


async def main():
    async with httpx.AsyncClient(timeout=120, follow_redirects=True) as client:
        response = await client.post(project + "/auth/v1/signup", headers={"apikey": config["publishableKey"]}, json={})
        response.raise_for_status()
        auth = response.json()
        headers = {"Authorization": "Bearer " + auth["access_token"]}
        session_id = str(uuid4())
        path = api + "/v1/listening/sessions/" + session_id
        response = await client.post(path, headers=headers)
        response.raise_for_status()
        assert response.json()["state"] == "ready", response.text
        response = await client.get(path + "/content", headers=headers)
        response.raise_for_status()
        manifest = response.json()
        assert len(manifest["questions"]) == 39
        assert sum(q["image"] is not None for q in manifest["questions"]) == 4
        assert all("correct_index" not in q and "transcript" not in q for q in manifest["questions"])
        assert manifest["questions"][0]["options"] == list("ABCD")
        for q in manifest["questions"]:
            for asset in [q["audio"]] + ([q["image"]] if q["image"] else []):
                media = await client.get(path + "/assets/" + asset["name"], headers=headers)
                media.raise_for_status()
                assert len(media.content) == asset["bytes"]
                assert hashlib.sha256(media.content).hexdigest() == asset["sha256"]
        assert (await client.get(path + "/content")).status_code == 401
        assert (await client.get(api + "/v1/listening/sessions/50f71ba1-5c93-4de7-b043-cf2c215fa4c6/content", headers=headers)).status_code == 404
        assert (await client.post(path + "/submit", headers=headers, json={"answers": {"1": 4}})).status_code == 422
        response = await client.post(project + "/auth/v1/token?grant_type=refresh_token", headers={"apikey": config["publishableKey"]}, json={"refresh_token": auth["refresh_token"]})
        response.raise_for_status()
        refreshed = response.json()
        assert refreshed["user"]["id"] == auth["user"]["id"]
        headers = {"Authorization": "Bearer " + refreshed["access_token"]}
        result = await client.post(path + "/submit", headers=headers, json={"answers": {str(i): 0 for i in range(1, 40)}})
        result.raise_for_status()
        result = result.json()
        assert len(result["questions"]) == 39
        assert result["correct"] == sum(q["correct_index"] == 0 for q in result["questions"])
        print(json.dumps({"automatic_auth": "passed", "refresh": "passed", "questions": 39, "assets": 43, "checksums": "passed", "grading": "passed", "private_seed": "protected"}), flush=True)

        if os.getenv("CHECK_CLOUD_WORKER") == "1":
            # Exercise a six-question batch and parallel audio, reusing the other 33 paid assets.
            admin_headers = {"apikey": os.environ["SUPABASE_SECRET_KEY"]}
            response = await client.get(project + "/rest/v1/tcf_listening_sessions", headers=admin_headers, params={"id": "eq." + session_id, "select": "*"})
            response.raise_for_status()
            row = response.json()[0]
            assets = {k: v for k, v in row["assets"].items() if k not in {f"audio-{i}.wav" for i in range(34, 40)}}
            update = await client.patch(project + "/rest/v1/tcf_listening_sessions?id=eq." + session_id, headers=admin_headers,
                                        json={"plan": row["plan"][:33], "planned": 33, "audio": 33, "state": "queued", "assets": assets, "error": None, "last_answers": None, "last_score": None, "completed_at": None})
            update.raise_for_status()
            started = time.monotonic()
            (await client.post(path, headers=headers)).raise_for_status()
            deadline = time.monotonic() + 360
            while True:
                response = await client.get(path, headers=headers)
                response.raise_for_status()
                status = response.json()
                if status["state"] == "failed":
                    raise RuntimeError(status["error"])
                if status["state"] == "ready":
                    break
                if time.monotonic() > deadline:
                    raise RuntimeError("Hosted worker did not finish within six minutes")
                await asyncio.sleep(3)
            final = await client.get(project + "/rest/v1/tcf_listening_sessions", headers=admin_headers, params={"id": "eq." + session_id, "select": "plan,assets"})
            final.raise_for_status()
            finished = final.json()[0]
            assert len(finished["plan"]) == 39
            assert all(finished["assets"][f"audio-{i}.wav"]["audio_version"] == 2 for i in range(34, 40))
            print(json.dumps({"hosted_new_questions": 6, "hosted_new_recordings": 6, "seconds": round(time.monotonic() - started, 1), "audio_version": 2}), flush=True)


if __name__ == "__main__":
    asyncio.run(main())
