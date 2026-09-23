"""Local UI-test server: no Azure credentials, calls, or charges."""
import asyncio
import os
import tempfile
from pathlib import Path

import uvicorn

from app import create_app
from service import SessionService
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
        uvicorn.run(create_app(FixtureProvider(), root, "ui-test-token"), host="127.0.0.1", port=8766, access_log=False)
