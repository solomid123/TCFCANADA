"""Verify owner-scoped test history and saved corrections without generating new content."""
import asyncio
import json
import plistlib
from pathlib import Path
from uuid import uuid4

import httpx


async def main():
    config = plistlib.loads((Path(__file__).resolve().parents[1] / "apptsst/CloudConfiguration.plist").read_bytes())
    project = config["projectURL"]
    api = project + "/functions/v1/listening-api/v1/listening/sessions"
    async with httpx.AsyncClient(timeout=90) as client:
        signed_in = await client.post(project + "/auth/v1/signup", headers={"apikey": config["publishableKey"]}, json={})
        signed_in.raise_for_status()
        auth = signed_in.json()
        headers = {"Authorization": "Bearer " + auth["access_token"]}
        before = await client.get(api, headers=headers)
        before.raise_for_status()
        assert before.json()["sessions"] == []
        assert before.json()["bank_count"] == 39
        session_id = str(uuid4())
        created = await client.post(api + "/" + session_id, headers=headers)
        created.raise_for_status()
        assert created.json()["state"] == "ready"
        prepared = (await client.get(api, headers=headers)).json()["sessions"]
        assert prepared[0]["id"] == session_id and prepared[0]["last_score"] is None
        answers = {str(i): 0 for i in range(1, 40)}
        graded = await client.post(api + "/" + session_id + "/submit", headers=headers, json={"answers": answers})
        graded.raise_for_status()
        score = graded.json()["correct"]
        saved = (await client.get(api, headers=headers)).json()["sessions"][0]
        assert saved["id"] == session_id and saved["last_score"] == score and saved["completed_at"]
        refreshed = await client.post(project + "/auth/v1/token?grant_type=refresh_token", headers={"apikey": config["publishableKey"]}, json={"refresh_token": auth["refresh_token"]})
        refreshed.raise_for_status()
        headers = {"Authorization": "Bearer " + refreshed.json()["access_token"]}
        restored = await client.get(api + "/" + session_id + "/attempt", headers=headers)
        restored.raise_for_status()
        assert restored.json()["answers"] == answers
        assert restored.json()["result"]["correct"] == score
        assert len(restored.json()["result"]["questions"]) == 39
        outsider = await client.post(project + "/auth/v1/signup", headers={"apikey": config["publishableKey"]}, json={})
        outsider.raise_for_status()
        outside_headers = {"Authorization": "Bearer " + outsider.json()["access_token"]}
        assert (await client.get(api + "/" + session_id + "/attempt", headers=outside_headers)).status_code == 404
        assert (await client.get(api, headers=outside_headers)).json()["sessions"] == []
        print(json.dumps({"prepared_tests_saved": True, "completed_score_saved": True, "all_39_corrections_restored": True, "owner_isolation": True, "verified_bank_count": 39}))


if __name__ == "__main__":
    asyncio.run(main())
