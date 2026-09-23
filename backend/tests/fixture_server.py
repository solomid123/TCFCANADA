"""Local UI-test server: no Azure credentials, calls, or charges."""
import asyncio
import os
import tempfile
import hashlib
import io
import json
import wave
from pathlib import Path
from uuid import UUID

import uvicorn
from fastapi import Header, HTTPException

from app import create_app
from service import SessionService, atomic_write, write_json
from tests.test_generation import FixtureProvider

SESSION_ID = "0c4c535b-2a87-4482-b071-fd232ae9dc4e"


async def seed(root):
    provider = FixtureProvider()
    store = SessionService(root, provider)
    store.start(SESSION_ID)
    await store.tasks[SESSION_ID]
    assert store.status(SESSION_ID)["state"] == "ready"
    await store.close()


if __name__ == "__main__":
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        asyncio.run(seed(root))
        app = create_app(FixtureProvider(), root, "ui-test-token")

        @app.post("/test/update-audio/{session_id}")
        def update_audio(session_id: UUID, authorization: str = Header(default="")):
            if authorization != "Bearer ui-test-token":
                raise HTTPException(401)
            folder = root / str(session_id)
            manifest = json.loads((folder / "content.json").read_text())
            output = io.BytesIO()
            with wave.open(output, "wb") as recording:
                recording.setnchannels(1)
                recording.setsampwidth(2)
                recording.setframerate(24000)
                recording.writeframes(b"\0" * 72000)
            data = output.getvalue()
            atomic_write(folder / "audio-1.wav", data)
            manifest["questions"][0]["audio"].update(sha256=hashlib.sha256(data).hexdigest(), bytes=len(data))
            manifest["questions"][0]["duration"] = 1.5
            write_json(folder / "content.json", manifest)
            return {"updated": True}

        uvicorn.run(app, host="127.0.0.1", port=8766, access_log=False)
