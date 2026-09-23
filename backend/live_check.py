"""Opt-in live integration check. Reuse an ID to avoid regenerating paid assets.

TCF_API_TOKEN=... python live_check.py <session-uuid>
The backend must already be running. This client waits for its asynchronous job.
"""
import asyncio
import hashlib
import json
import os
import sys
from uuid import UUID

import httpx


async def main():
    session_id = str(UUID(sys.argv[1]))
    root = os.getenv("TCF_BACKEND_URL", "http://127.0.0.1:8765")
    path = f"/v1/listening/sessions/{session_id}"
    async with httpx.AsyncClient(base_url=root, headers={"Authorization": f"Bearer {os.environ['TCF_API_TOKEN']}"}, timeout=60) as client:
        response = await client.post(path + "?retry=true")
        response.raise_for_status()
        while True:
            response = await client.get(path)
            response.raise_for_status()
            status = response.json()
            if status["state"] == "failed":
                raise RuntimeError(status["error"])
            if status["state"] == "ready":
                break
            await asyncio.sleep(3)
        response = await client.get(path + "/content")
        response.raise_for_status()
        manifest = response.json()
        assert len(manifest["questions"]) == 39
        assert sum(bool(question["image"]) for question in manifest["questions"]) == 4
        assert all("correct_index" not in question and "transcript" not in question for question in manifest["questions"])
        for question in manifest["questions"]:
            for asset in [question["audio"]] + ([question["image"]] if question["image"] else []):
                media = await client.get(path + "/assets/" + asset["name"])
                media.raise_for_status()
                assert len(media.content) == asset["bytes"]
                assert hashlib.sha256(media.content).hexdigest() == asset["sha256"]
        response = await client.post(path + "/submit", json={"answers": {str(number): 0 for number in range(1, 40)}})
        response.raise_for_status()
        result = response.json()
        assert result["answered"] == 39 and len(result["questions"]) == 39
        assert result["correct"] == sum(question["correct_index"] == 0 for question in result["questions"])
        repeated = await client.post(path)
        assert repeated.json()["state"] == "ready"
        print(json.dumps({"session": session_id, "questions": 39, "images": 4, "audio_files": 39,
                          "checksums": "passed", "grading": "passed", "reuse": "passed",
                          "audio_minutes": round(sum(q["duration"] for q in manifest["questions"]) / 60, 1)}))


if __name__ == "__main__":
    asyncio.run(main())
