import asyncio
import base64
import io
import json
import os
from xml.sax.saxutils import escape, quoteattr

import httpx
from PIL import Image

from schemas import Batch, Question, blueprint


class ProviderError(Exception):
    pass


class AzureProvider:
    def __init__(self):
        self.key = os.environ.get("AZURE_API_KEY", "")
        self.speech_key = os.environ.get("AZURE_SPEECH_KEY") or self.key
        if not self.key:
            raise RuntimeError("AZURE_API_KEY is required")
        self.text_endpoint = os.getenv("AZURE_OPENAI_ENDPOINT", "https://nedolinko-0140-resource.services.ai.azure.com/openai/v1").rstrip("/")
        self.model = os.getenv("AZURE_TEXT_DEPLOYMENT", "DeepSeek-V4-Flash")
        self.vision_model = os.getenv("AZURE_VISION_DEPLOYMENT", "grok-4.6")
        self.reasoning_effort = os.getenv("AZURE_REASONING_EFFORT", "low")
        self.image_endpoint = os.getenv("AZURE_IMAGE_ENDPOINT", "https://nedolinko-0140-resource.services.ai.azure.com/providers/blackforestlabs/v1/flux-2-pro?api-version=preview")
        self.speech_endpoint = os.getenv("AZURE_SPEECH_ENDPOINT", "https://nedolinko-0140-resource.cognitiveservices.azure.com").rstrip("/")
        self.voices = {
            "female": os.getenv("AZURE_VOICE_FEMALE", "fr-CA-SylvieNeural"),
            "male": os.getenv("AZURE_VOICE_MALE", "fr-CA-ThierryNeural"),
        }
        self.client = httpx.AsyncClient(timeout=httpx.Timeout(360, connect=20))
        self.usage: list[dict] = []

    async def close(self):
        await self.client.aclose()

    async def request(self, url: str, **kwargs) -> httpx.Response:
        for attempt in range(3):
            try:
                response = await self.client.post(url, **kwargs)
            except httpx.ReadTimeout as error:
                # The provider may already have billed this request. Do not silently repeat it.
                raise ProviderError("Le fournisseur met trop de temps à répondre. Les éléments prêts sont conservés ; vous pouvez reprendre la préparation.") from error
            except httpx.TransportError as error:
                if attempt == 2:
                    raise ProviderError("Connexion au fournisseur interrompue. Réessayez.") from error
                await asyncio.sleep(2 ** attempt)
                continue
            if response.is_success:
                return response
            if response.status_code in (408, 429, 500, 502, 503, 504) and attempt < 2:
                await asyncio.sleep(2 ** (attempt + 1))
                continue
            # Do not send provider response bodies, resource details or credentials to clients.
            raise ProviderError(f"Le fournisseur a refusé une requête (HTTP {response.status_code}). Vérifiez la configuration du serveur.")
        raise ProviderError("Service temporairement indisponible.")

    async def chat(self, messages: list[dict], max_tokens: int, model: str | None = None) -> dict:
        deployment = model or self.model
        response = await self.request(
            f"{self.text_endpoint}/chat/completions",
            headers={"api-key": self.key},
            json={"model": deployment, "messages": messages, "max_tokens": max_tokens, **({"reasoning_effort": self.reasoning_effort} if deployment.startswith("grok") else {}),
                  "response_format": {"type": "json_object"}, "stream": True, "stream_options": {"include_usage": True}},
        )
        # SSE keeps the connection active during long generations. The completed response is
        # assembled before validation; an interrupted stream is never published as a question batch.
        content = []
        finish_reason = None
        usage = {}
        try:
            for line in response.text.splitlines():
                if not line.startswith("data:"):
                    continue
                event = line[5:].strip()
                if event == "[DONE]":
                    continue
                chunk = json.loads(event)
                if chunk.get("usage"):
                    usage = chunk["usage"]
                for choice in chunk.get("choices", []):
                    if choice.get("index") == 0:
                        content.append(choice.get("delta", {}).get("content") or "")
                        finish_reason = choice.get("finish_reason") or finish_reason
        except (ValueError, TypeError) as error:
            raise ProviderError("Le flux de génération a été interrompu.") from error
        self.usage.append(usage)
        if finish_reason != "stop":
            raise ProviderError("La génération du texte est incomplète. Réessayez.")
        try:
            return json.loads("".join(content))
        except (ValueError, KeyError, TypeError) as error:
            raise ProviderError("Le modèle a renvoyé un format de texte invalide.") from error

    async def questions(self, numbers: list[int], seed: str, previous_topics: list[str]) -> list[Question]:
        plan = [{"id": number, "kind": blueprint(number)[0], "level": blueprint(number)[1]} for number in numbers]
        system = """You are a meticulous French listening-exercise author. Produce ORIGINAL TCF-style training content,
not official exam items. Output JSON only: {"questions": [...]}. Every question must follow the supplied id/kind/level.
Each question has EXACT keys: id, kind, level, question (French), turns [{speaker: "female"|"male", text: French}],
options (4 distinct French strings WITHOUT A/B/C/D prefixes), correct_index (0..3), explanation (French), image_prompt.
Exactly ONE answer must be unambiguously correct. Explain the supporting evidence and why distractors are wrong.
Check your own answer key before returning. Distribute correct_index across A/B/C/D, avoiding a repeated pattern.
Use natural Canadian French, varied ordinary Canadian/Francophone settings and topics. No real personal data.
Do not include answers, explanations, speaker labels, or stage directions in turns.
picture: ONE clear scene, not a collage. image_prompt is a detailed English illustration prompt with no text, labels,
logos or numbers. Specify visible details so exactly ONE of the four spoken propositions matches. All 4 options are
short descriptions of the image; distractors must visibly contradict it. turns contains one brief neutral instruction
only (not a description that reveals the answer). question = "Quelle proposition correspond à l'image ?".
response: turns contains a short spoken question or statement. The 4 options are possible spoken replies. Only one
fits naturally; the other three must be clearly inappropriate. question = "Choisissez la réponse qui convient.".
For picture/response, the server will append A/B/C/D and the four options to the audio. DO NOT put them in turns.
dialogue: a realistic 2-speaker conversation (female and male), 3–6 turns, 50–110 total words. The question is about
the conversation. Options are written answers, not a continuation of the dialogue.
report: 1–2 turns, 90–180 words total. Use interviews, radio reports, explanations and viewpoints. Advanced questions
test inference, tone, implied criticism, nuance or intent. Include actual evidence, not a trivia knowledge test.
image_prompt is null for EVERY non-picture question. Keep explanations under 90 words, options under 25 words.
Difficulty should increase through the supplied levels. No Markdown. Avoid repeating previous topics."""
        prompt = {"training_seed": seed, "blueprint": plan, "previous_topics": previous_topics}
        last_error = ""
        for _ in range(2):
            result = await self.chat([
                {"role": "system", "content": system},
                {"role": "user", "content": json.dumps(prompt, ensure_ascii=False) + last_error},
            ], max_tokens=15000)
            try:
                batch = Batch.model_validate(result)
                if [question.id for question in batch.questions] != numbers:
                    raise ValueError("Return every requested id exactly once in ascending order")
                return batch.questions
            except ValueError as error:
                last_error = "\nYour previous response failed validation. Correct these issues: " + str(error)[:1200]
        raise ProviderError("Les questions ne respectent pas le format attendu. Réessayez.")

    async def image(self, question: Question) -> bytes:
        response = await self.request(
            self.image_endpoint, headers={"Authorization": f"Bearer {self.key}"},
            json={"model": "FLUX.2-pro", "prompt": question.image_prompt, "width": 1024, "height": 1024, "n": 1},
        )
        try:
            data = base64.b64decode(response.json()["data"][0]["b64_json"], validate=True)
            with Image.open(io.BytesIO(data)) as image:
                image.load()
                output = io.BytesIO()
                image.convert("RGB").save(output, format="PNG")
                return output.getvalue()
        except (ValueError, KeyError, IndexError, OSError) as error:
            raise ProviderError("L'image générée est invalide.") from error

    async def check_image(self, question: Question, image: bytes) -> bool:
        result = await self.chat([
            {"role": "system", "content": "Check a French listening picture exercise against the ACTUAL image. Return JSON {\"valid\":true|false,\"matching_index\":0|1|2|3|null}. valid is true ONLY if exactly one proposition clearly matches visible evidence. Do not guess hidden facts."},
            {"role": "user", "content": [
                {"type": "text", "text": json.dumps(question.options, ensure_ascii=False)},
                {"type": "image_url", "image_url": {"url": "data:image/png;base64," + base64.b64encode(image).decode(), "detail": "low"}},
            ]},
        ], max_tokens=600, model=self.vision_model)
        return result.get("valid") is True and type(result.get("matching_index")) is int and result["matching_index"] == question.correct_index

    def transcript(self, question: Question) -> str:
        parts = [turn.text for turn in question.turns]
        if question.kind in ("picture", "response"):
            parts += [f"Proposition {letter}. {option}" for letter, option in zip("ABCD", question.options)]
        else:
            parts.append(question.question)
        return "\n\n".join(parts)

    def ssml(self, question: Question) -> str:
        parts = []
        for index, turn in enumerate(question.turns):
            lead_in = '<break time="900ms"/>' if index == 0 else ""
            parts.append(f"<voice name={quoteattr(self.voices[turn.speaker])}><lang xml:lang=\"fr-CA\">{lead_in}{escape(turn.text)}</lang><break time=\"600ms\"/></voice>")
        ending = "".join(f"Proposition {letter}.<break time=\"700ms\"/>{escape(option)}<break time=\"1500ms\"/>" for letter, option in zip("ABCD", question.options)) if question.kind in ("picture", "response") else escape(question.question)
        parts.append(f"<voice name={quoteattr(self.voices['female'])}><lang xml:lang=\"fr-CA\"><break time=\"900ms\"/>{ending}</lang></voice>")
        return '<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="fr-CA">' + "".join(parts) + '</speak>'

    async def audio(self, question: Question) -> bytes:
        response = await self.request(
            f"{self.speech_endpoint}/tts/cognitiveservices/v1",
            headers={"Ocp-Apim-Subscription-Key": self.speech_key, "Content-Type": "application/ssml+xml",
                     "X-Microsoft-OutputFormat": "riff-24khz-16bit-mono-pcm", "User-Agent": "TCFCanada"},
            content=self.ssml(question).encode(),
        )
        return response.content
