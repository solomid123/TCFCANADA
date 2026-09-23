import hmac
import os
import re
from contextlib import asynccontextmanager
from pathlib import Path
from uuid import UUID

from dotenv import load_dotenv
from fastapi import Depends, FastAPI, Header, HTTPException, Request
from fastapi.responses import FileResponse

from providers import AzureProvider, ProviderError
from schemas import Submission
from service import SessionService

load_dotenv(Path(__file__).parent / ".env")


def create_app(provider=None, data_dir: Path | None = None, token: str | None = None):
    access_token = token if token is not None else os.getenv("TCF_API_TOKEN", "")

    @asynccontextmanager
    async def lifespan(app):
        if not access_token:
            raise RuntimeError("TCF_API_TOKEN is required; configure the same backend token in the app")
        root = data_dir or Path(os.getenv("TCF_DATA_DIR", str(Path(__file__).parent / "data")))
        app.state.service = SessionService(root, provider or AzureProvider(), int(os.getenv("TCF_DAILY_SESSION_LIMIT", "8")))
        app.state.service.recover()
        yield
        await app.state.service.close()

    app = FastAPI(title="TCF listening generation", lifespan=lifespan)

    async def authenticate(authorization: str = Header(default="")):
        if not hmac.compare_digest(authorization, f"Bearer {access_token}"):
            raise HTTPException(401, "Connexion au serveur non autorisée. Vérifiez le jeton d'accès.")

    def service(request: Request):
        return request.app.state.service

    @app.exception_handler(ProviderError)
    async def provider_error(request, error):
        from fastapi.responses import JSONResponse
        return JSONResponse(status_code=409, content={"detail": str(error)})

    @app.exception_handler(FileNotFoundError)
    async def missing_session(request, error):
        from fastapi.responses import JSONResponse
        return JSONResponse(status_code=404, content={"detail": "Session introuvable."})

    @app.get("/health")
    async def health():
        return {"status": "ok"}

    @app.post("/v1/listening/sessions/{session_id}", dependencies=[Depends(authenticate)])
    async def start(session_id: UUID, retry: bool = False, store=Depends(service)):
        return store.start(str(session_id), retry)

    @app.get("/v1/listening/sessions/{session_id}", dependencies=[Depends(authenticate)])
    async def status(session_id: UUID, store=Depends(service)):
        return store.status(str(session_id))

    @app.get("/v1/listening/sessions/{session_id}/content", dependencies=[Depends(authenticate)])
    async def content(session_id: UUID, store=Depends(service)):
        return store.content(str(session_id))

    @app.get("/v1/listening/sessions/{session_id}/assets/{name}", dependencies=[Depends(authenticate)])
    async def asset(session_id: UUID, name: str, store=Depends(service)):
        store.content(str(session_id))
        if not re.fullmatch(r"(?:audio-\d+\.wav|image-\d+\.png)", name):
            raise HTTPException(404)
        path = store.folder(str(session_id)) / name
        if not path.is_file():
            raise HTTPException(404)
        return FileResponse(path, media_type="audio/wav" if name.endswith(".wav") else "image/png")

    @app.post("/v1/listening/sessions/{session_id}/submit", dependencies=[Depends(authenticate)])
    async def submit(session_id: UUID, body: Submission, store=Depends(service)):
        return store.submit(str(session_id), body.answers)

    return app


app = create_app()
