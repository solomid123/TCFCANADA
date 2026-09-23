import asyncio
import hashlib
import io
import json
import logging
import os
import time
import wave
from pathlib import Path
from uuid import UUID

from providers import ProviderError
from schemas import Batch, Question

logger = logging.getLogger("tcf.generation")


def atomic_write(path: Path, data: bytes):
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_bytes(data)
    temporary.replace(path)


def write_json(path: Path, value):
    atomic_write(path, json.dumps(value, ensure_ascii=False).encode())


class SessionService:
    def __init__(self, root: Path, provider, daily_limit: int = 8):
        self.root = root
        root.mkdir(parents=True, exist_ok=True)
        self.provider = provider
        self.daily_limit = daily_limit
        self.tasks: dict[str, asyncio.Task] = {}
        self.worker_limit = asyncio.Semaphore(1)
        self.media_limit = asyncio.Semaphore(2)

    def folder(self, session_id: str) -> Path:
        return self.root / str(UUID(session_id))

    def status(self, session_id: str) -> dict:
        return json.loads((self.folder(session_id) / "status.json").read_text())

    def save_status(self, session_id: str, **updates):
        status = self.status(session_id)
        status.update(updates)
        write_json(self.folder(session_id) / "status.json", status)
        return status

    def start(self, session_id: str, retry: bool = False) -> dict:
        folder = self.folder(session_id)
        if not folder.exists():
            recent = sum(1 for path in self.root.glob("*/status.json") if json.loads(path.read_text()).get("created_at", path.stat().st_mtime) > time.time() - 86400)
            if recent >= self.daily_limit:
                raise ProviderError("Limite quotidienne de nouvelles sessions atteinte. Réutilisez une session préparée.")
            folder.mkdir()
            write_json(folder / "status.json", {"id": session_id, "created_at": time.time(), "state": "queued", "phase": "En attente", "planned": 0, "images": 0, "audio": 0, "total": 39, "error": None})
        status = self.status(session_id)
        if status["state"] == "ready" or (status["state"] == "failed" and not retry):
            return status
        if session_id not in self.tasks or self.tasks[session_id].done():
            self.save_status(session_id, state="queued", error=None)
            self.tasks[session_id] = asyncio.create_task(self.generate(session_id))
        return self.status(session_id)

    def recover(self):
        # Persisted batches/media survive process restarts. Jobs resume on the next app request.
        for path in self.root.glob("*/status.json"):
            try:
                status = json.loads(path.read_text())
                if status["state"] in ("queued", "generating"):
                    status.update(state="interrupted", phase="Préparation à reprendre")
                    write_json(path, status)
            except (ValueError, KeyError):
                logger.warning("Ignoring invalid session status file")

    async def close(self):
        for task in self.tasks.values():
            task.cancel()
        await asyncio.gather(*self.tasks.values(), return_exceptions=True)
        await self.provider.close()

    async def generate(self, session_id: str):
        async with self.worker_limit:
            folder = self.folder(session_id)
            usage_start = len(self.provider.usage)
            try:
                self.save_status(session_id, state="generating", phase="Création des questions", error=None)
                questions: list[Question] = []
                for batch_index in range(3):
                    path = folder / f"batch-{batch_index}.json"
                    numbers = list(range(batch_index * 13 + 1, batch_index * 13 + 14))
                    if path.exists():
                        batch = Batch.model_validate_json(path.read_text()).questions
                    else:
                        batch = await self.provider.questions(numbers, session_id, [question.question for question in questions])
                        if [question.id for question in batch] != numbers:
                            raise ProviderError("Le nombre de questions générées est incorrect.")
                        write_json(path, {"questions": [question.model_dump() for question in batch]})
                    questions.extend(batch)
                    self.save_status(session_id, planned=len(questions))
                if [question.id for question in questions] != list(range(1, 40)):
                    raise ProviderError("Session incomplète.")

                # Images first: do not pay for audio if the visual exercises cannot be validated.
                self.save_status(session_id, phase="Création et vérification des images")
                for question in questions[:4]:
                    image_path = folder / f"image-{question.id}.png"
                    if not image_path.exists():
                        for attempt in range(2):
                            image = await self.provider.image(question)
                            if await self.provider.check_image(question, image):
                                atomic_write(image_path, image)
                                break
                            if attempt == 1:
                                raise ProviderError("Une image ne correspond pas assez clairement à sa réponse. Réessayez pour la remplacer.")
                    self.save_status(session_id, images=question.id)

                self.save_status(session_id, phase="Préparation des voix canadiennes")
                # TaskGroup cancels siblings on failure; a retry never races an old writer.
                async with asyncio.TaskGroup() as group:
                    for question in questions:
                        group.create_task(self.generate_audio(session_id, question))

                public_questions = []
                review = []
                for question in questions:
                    audio = folder / f"audio-{question.id}.wav"
                    with wave.open(str(audio), "rb") as recording:
                        duration = recording.getnframes() / recording.getframerate()
                    item = {"id": question.id, "kind": question.kind, "level": question.level, "question": question.question,
                            "options": list("ABCD") if question.kind in ("picture", "response") else question.options,
                            "audio": self.asset(audio), "image": self.asset(folder / f"image-{question.id}.png") if question.kind == "picture" else None,
                            "duration": duration}
                    public_questions.append(item)
                    review.append({"id": question.id, "options": question.options, "correct_index": question.correct_index,
                                   "explanation": question.explanation, "transcript": self.provider.transcript(question)})
                write_json(folder / "content.json", {"id": session_id, "title": "Écoute · Session IA", "questions": public_questions})
                write_json(folder / "review.json", review)
                write_json(folder / "usage.json", {"text_requests": self.provider.usage[usage_start:], "image_count": 4, "audio_count": 39, "voices": self.provider.voices})
                self.save_status(session_id, state="ready", phase="Votre session est prête", error=None)
            except asyncio.CancelledError:
                self.save_status(session_id, state="interrupted", phase="Préparation à reprendre")
                raise
            except Exception as error:
                # ExceptionGroups come from media tasks. Use only our sanitized error messages.
                cause = error
                while isinstance(cause, BaseExceptionGroup) and cause.exceptions:
                    cause = cause.exceptions[0]
                message = str(cause) if isinstance(cause, ProviderError) else "Préparation interrompue. Réessayez ; les éléments prêts seront conservés."
                logger.warning("Session %s failed (%s)", session_id, type(cause).__name__)
                self.save_status(session_id, state="failed", error=message)

    async def generate_audio(self, session_id: str, question: Question):
        async with self.media_limit:
            folder = self.folder(session_id)
            path = folder / f"audio-{question.id}.wav"
            if not path.exists():
                data = await self.provider.audio(question)
                try:
                    with wave.open(io.BytesIO(data), "rb") as recording:
                        if recording.getnframes() / recording.getframerate() < 0.2:
                            raise ValueError("Empty recording")
                except (wave.Error, EOFError, ValueError) as error:
                    raise ProviderError("Un enregistrement audio est invalide.") from error
                atomic_write(path, data)
            self.save_status(session_id, audio=len(list(folder.glob("audio-*.wav"))))

    @staticmethod
    def asset(path: Path) -> dict:
        data = path.read_bytes()
        return {"name": path.name, "sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data)}

    def content(self, session_id: str) -> dict:
        if self.status(session_id)["state"] != "ready":
            raise ProviderError("La session n'est pas encore prête.")
        return json.loads((self.folder(session_id) / "content.json").read_text())

    def submit(self, session_id: str, answers: dict[int, int]) -> dict:
        self.content(session_id)
        review = json.loads((self.folder(session_id) / "review.json").read_text())
        correct = sum(answers.get(item["id"]) == item["correct_index"] for item in review)
        return {"correct": correct, "total": 39, "answered": len(answers), "questions": review}
