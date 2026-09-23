import asyncio
import base64
import io
import os
import tempfile
import unittest
import wave
from collections import Counter
from pathlib import Path
from uuid import uuid4
from unittest.mock import patch

import httpx
from fastapi.testclient import TestClient
from pydantic import ValidationError

from app import create_app
from providers import AzureProvider, ProviderError
from schemas import Question, Submission, blueprint
from service import SessionService


class FixtureProvider(AzureProvider):
    """Deterministic test double. Never selected by the production application."""
    def __init__(self):
        self.calls = Counter()
        self.audio_calls = Counter()
        self.fail_audio = None
        self.valid_image = True
        self.usage = []
        self.voices = {"female": "fr-CA-SylvieNeural", "male": "fr-CA-ThierryNeural"}

    async def close(self):
        pass

    async def questions(self, numbers, seed, previous_topics):
        self.calls["questions"] += 1
        result = []
        for number in numbers:
            kind, level = blueprint(number)
            turns = [{"speaker": "female", "text": "Bonjour, à quelle heure arrive le train ?"}]
            if kind == "dialogue":
                turns.append({"speaker": "male", "text": "Il arrive à dix heures, sur la voie numéro deux."})
            result.append(Question(id=number, kind=kind, level=level, question=f"Question de test {number} : quelle réponse convient ?", turns=turns,
                                  options=["À dix heures.", "Au marché.", "En voiture.", "Un café."],
                                  correct_index=(number - 1) % 4, explanation="La bonne réponse correspond à l'information explicitement donnée dans l'extrait.",
                                  image_prompt="A person waiting for a train, no text" if kind == "picture" else None))
        return result

    async def image(self, question):
        self.calls["images"] += 1
        return base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=")

    async def check_image(self, question, image):
        self.calls["image_checks"] += 1
        return self.valid_image

    async def audio(self, question):
        self.audio_calls[question.id] += 1
        if self.fail_audio == question.id:
            raise ProviderError("Test audio failure")
        output = io.BytesIO()
        with wave.open(output, "wb") as recording:
            recording.setnchannels(1)
            recording.setsampwidth(2)
            recording.setframerate(24000)
            recording.writeframes(b"\0" * 24000)
        return output.getvalue()


class GenerationTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.provider = FixtureProvider()
        self.service = SessionService(Path(self.temporary.name), self.provider)
        self.session_id = str(uuid4())

    async def asyncTearDown(self):
        await self.service.close()
        self.temporary.cleanup()

    async def generate(self, retry=False):
        self.service.start(self.session_id, retry=retry)
        if self.session_id in self.service.tasks:
            await self.service.tasks[self.session_id]

    async def test_complete_session_hides_answers_and_grades_correctly(self):
        await self.generate()
        manifest = self.service.content(self.session_id)
        self.assertEqual(len(manifest["questions"]), 39)
        self.assertEqual(sum(q["image"] is not None for q in manifest["questions"]), 4)
        for question in manifest["questions"]:
            self.assertNotIn("correct_index", question)
            self.assertNotIn("transcript", question)
            self.assertNotIn("explanation", question)
            if question["kind"] in ("picture", "response"):
                self.assertEqual(question["options"], list("ABCD"))
        result = self.service.submit(self.session_id, {i: (i - 1) % 4 for i in range(1, 40)})
        self.assertEqual(result["correct"], 39)
        self.assertEqual(result["answered"], 39)
        self.assertEqual(len(result["questions"]), 39)
        self.assertEqual(self.service.submit(self.session_id, {})["correct"], 0)

    async def test_reopening_and_duplicate_requests_do_not_regenerate(self):
        self.service.start(self.session_id)
        original_task = self.service.tasks[self.session_id]
        self.service.start(self.session_id)
        self.assertIs(self.service.tasks[self.session_id], original_task)
        await original_task
        await self.generate()
        self.assertEqual(self.provider.calls["questions"], 3)
        self.assertEqual(self.provider.calls["images"], 4)
        self.assertEqual(sum(self.provider.audio_calls.values()), 39)

    async def test_retry_only_generates_missing_audio(self):
        self.provider.fail_audio = 7
        await self.generate()
        self.assertEqual(self.service.status(self.session_id)["state"], "failed")
        self.assertEqual(self.provider.audio_calls[1], 1)
        self.provider.fail_audio = None
        await self.generate(retry=True)
        self.assertEqual(self.service.status(self.session_id)["state"], "ready")
        self.assertEqual(self.provider.calls["questions"], 3)
        self.assertEqual(self.provider.calls["images"], 4)
        self.assertEqual(self.provider.audio_calls[1], 1)
        self.assertEqual(self.provider.audio_calls[7], 2)

    async def test_ambiguous_image_blocks_audio_and_can_be_retried(self):
        self.provider.valid_image = False
        await self.generate()
        self.assertEqual(self.service.status(self.session_id)["state"], "failed")
        self.assertEqual(sum(self.provider.audio_calls.values()), 0)
        self.assertEqual(self.provider.calls["images"], 2)
        self.provider.valid_image = True
        await self.generate(retry=True)
        self.assertEqual(self.service.status(self.session_id)["state"], "ready")
        self.assertEqual(self.provider.calls["questions"], 3)

    async def test_spoken_choices_are_in_audio_but_not_answer_or_explanation(self):
        question = (await self.provider.questions([1], "test", []))[0]
        question.turns[0].text = "Écoutez & choisissez <une réponse>."
        ssml = self.provider.ssml(question)
        self.assertIn("&amp;", ssml)
        self.assertIn("&lt;une réponse&gt;", ssml)
        self.assertIn('Proposition A.<break time="700ms"/>À dix heures.', ssml)
        self.assertIn('<break time="900ms"/>Écoutez', ssml)
        self.assertIn('<break time="1500ms"/>Proposition B.', ssml)
        self.assertEqual(ssml.count("Proposition "), 4)
        self.assertNotIn(question.explanation, ssml)
        self.assertIn("fr-CA-SylvieNeural", ssml)

    async def test_validation_rejects_ambiguous_choices_and_invalid_answers(self):
        question = (await self.provider.questions([1], "test", []))[0].model_dump()
        question["options"][1] = question["options"][0].upper()
        with self.assertRaises(ValidationError):
            Question.model_validate(question)
        for answers in ({40: 0}, {1: 4}, {0: 0}, {1: -1}):
            with self.assertRaises(ValidationError):
                Submission(answers=answers)


class APITests(unittest.TestCase):
    def test_authentication_and_private_files(self):
        with tempfile.TemporaryDirectory() as directory:
            app = create_app(FixtureProvider(), Path(directory), "test-token")
            with TestClient(app) as client:
                session = str(uuid4())
                path = f"/v1/listening/sessions/{session}"
                self.assertEqual(client.post(path).status_code, 401)
                headers = {"Authorization": "Bearer test-token"}
                self.assertEqual(client.get(path, headers=headers).status_code, 404)
                self.assertEqual(client.post(path + "/submit", headers=headers, json={"answers": {"1": 9}}).status_code, 422)
                self.assertEqual(client.post("/v1/listening/sessions/not-a-uuid", headers=headers).status_code, 422)


class ProviderCostTests(unittest.IsolatedAsyncioTestCase):
    async def test_stream_assembles_only_complete_content_and_records_usage(self):
        async def stream(request):
            import json
            body = json.loads(request.content)
            self.assertTrue(body["stream"])
            self.assertEqual(body["model"], "DeepSeek-V4-Flash")
            self.assertNotIn("reasoning_effort", body)
            events = [
                {"choices": [{"index": 0, "delta": {"content": '{"status":'}}]},
                {"choices": [{"index": 0, "delta": {"content": '"ok"}'}, "finish_reason": "stop"}]},
                {"choices": [], "usage": {"total_tokens": 42}},
            ]
            return httpx.Response(200, text="\n\n".join("data: " + json.dumps(event) for event in events) + "\n\ndata: [DONE]\n")

        with patch.dict(os.environ, {"AZURE_API_KEY": "test-only", "AZURE_TEXT_DEPLOYMENT": "DeepSeek-V4-Flash"}):
            provider = AzureProvider()
        await provider.client.aclose()
        provider.client = httpx.AsyncClient(transport=httpx.MockTransport(stream))
        try:
            self.assertEqual(await provider.chat([{"role": "user", "content": "test"}], 64), {"status": "ok"})
            self.assertEqual(provider.usage[-1]["total_tokens"], 42)
        finally:
            await provider.close()

    async def test_read_timeout_does_not_repeat_a_potentially_billed_request(self):
        calls = 0

        async def timeout(request):
            nonlocal calls
            calls += 1
            raise httpx.ReadTimeout("Provider did not finish", request=request)

        with patch.dict(os.environ, {"AZURE_API_KEY": "test-only"}):
            provider = AzureProvider()
        await provider.client.aclose()
        provider.client = httpx.AsyncClient(transport=httpx.MockTransport(timeout))
        try:
            with self.assertRaises(ProviderError):
                await provider.chat([{"role": "user", "content": "test"}], 64)
            self.assertEqual(calls, 1)
        finally:
            await provider.close()

    async def test_provider_failure_does_not_expose_response_body(self):
        async def reject(request):
            return httpx.Response(403, json={"detail": "private-provider-diagnostics"})

        with patch.dict(os.environ, {"AZURE_API_KEY": "test-only"}):
            provider = AzureProvider()
        await provider.client.aclose()
        provider.client = httpx.AsyncClient(transport=httpx.MockTransport(reject))
        try:
            with self.assertRaises(ProviderError) as failure:
                await provider.chat([{"role": "user", "content": "test"}], 64)
            self.assertNotIn("private-provider-diagnostics", str(failure.exception))
        finally:
            await provider.close()


if __name__ == "__main__":
    unittest.main()
