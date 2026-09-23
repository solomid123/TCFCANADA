"""Upgrade saved spoken-choice audio without modifying questions, answers or scores.

Identical scripts share one synthesis request. Existing storage objects are retained
for clients that still have their previous signed URLs.
"""
import asyncio
import hashlib
import io
import json
import os
import sys
import wave
from pathlib import Path

import httpx
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[1]
load_dotenv(ROOT / "backend/.env")
sys.path.insert(0, str(ROOT / "backend"))
from providers import AzureProvider
from schemas import Question


async def main():
    url = os.environ["SUPABASE_URL"]
    key = {"apikey": os.environ["SUPABASE_SECRET_KEY"]}
    cache_dir = ROOT / "backend/data/audio-v2"
    cache_dir.mkdir(parents=True, exist_ok=True)
    provider = AzureProvider()
    async with httpx.AsyncClient(timeout=180) as client:
        offset = 0
        pending = {}
        while True:
            response = await client.get(url + "/rest/v1/tcf_listening_sessions", headers=key,
                                        params={"select": "id,plan,assets", "state": "eq.ready", "order": "id", "offset": offset, "limit": 100})
            response.raise_for_status()
            rows = response.json()
            for row in rows:
                for item in row["plan"]:
                    if item["kind"] not in ("picture", "response"):
                        continue
                    name = f"audio-{item['id']}.wav"
                    asset = row["assets"].get(name)
                    if not asset or asset.get("audio_version", 0) >= 2:
                        continue
                    question = Question.model_validate(item)
                    identity = hashlib.sha256(provider.ssml(question).encode()).hexdigest()
                    entry = pending.setdefault(identity, {"question": question, "references": []})
                    entry["references"].append((row["id"], name, asset["sha256"]))
            if len(rows) < 100:
                break
            offset += len(rows)
        print(f"Refreshing {sum(len(v['references']) for v in pending.values())} saved clips from {len(pending)} unique scripts.", flush=True)
        limit = asyncio.Semaphore(3)

        async def upgrade(identity, entry):
            async with limit:
                path = cache_dir / (identity + ".wav")
                if not path.exists():
                    audio = await provider.audio(entry["question"])
                    with wave.open(io.BytesIO(audio), "rb") as recording:
                        assert recording.getnframes() > 0
                    temporary = path.with_suffix(".tmp")
                    temporary.write_bytes(audio)
                    temporary.replace(path)
                data = path.read_bytes()
                with wave.open(io.BytesIO(data), "rb") as recording:
                    duration = recording.getnframes() / recording.getframerate()
                sha = hashlib.sha256(data).hexdigest()
                storage_path = f"audio-v2/{identity}.wav"
                response = await client.post(url + "/storage/v1/object/tcf-listening-private/" + storage_path,
                                             headers={**key, "Content-Type": "audio/wav", "x-upsert": "true"}, content=data)
                response.raise_for_status()
                changed = 0
                for session, name, old_sha in entry["references"]:
                    response = await client.post(url + "/rest/v1/rpc/upgrade_tcf_audio_asset", headers=key,
                                                 json={"p_session": session, "p_name": name, "p_old_sha": old_sha,
                                                       "p_asset": {"name": name, "path": storage_path, "sha256": sha, "bytes": len(data), "duration": duration, "audio_version": 2}})
                    response.raise_for_status()
                    changed += response.json() is True
                return changed

        try:
            updated = sum(await asyncio.gather(*(upgrade(identity, entry) for identity, entry in pending.items())))
            print(json.dumps({"updated_saved_clips": updated, "unique_audio_files": len(pending), "audio_version": 2}), flush=True)
        finally:
            await provider.close()


if __name__ == "__main__":
    asyncio.run(main())
