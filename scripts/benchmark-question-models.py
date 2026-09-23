"""Compare real three-question requests on the configured Azure deployments."""
import asyncio
import json
import os
import re
import sys
import time
from pathlib import Path

import httpx
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[1]
load_dotenv(ROOT / "backend/.env")
sys.path.insert(0, str(ROOT / "backend"))
from schemas import Batch, blueprint


async def main():
    source = (ROOT / "supabase/functions/listening-api/index.ts").read_text()
    prompt = re.search(r'content: `(Write original French listening practice.*?)`', source, re.S).group(1)
    numbers = [11, 12, 13]
    messages = [
        {"role": "system", "content": prompt},
        {"role": "user", "content": json.dumps({"blueprint": [{"id": n, "kind": blueprint(n)[0], "level": blueprint(n)[1]} for n in numbers], "previous_topics": [], "seed": "latency-check"})},
    ]

    async def run(model):
        start = time.monotonic()
        first = None
        text = ""
        usage = {}
        finish = None
        body = {"model": model, "messages": messages, "max_tokens": 5000, "response_format": {"type": "json_object"}, "stream": True, "stream_options": {"include_usage": True}}
        if model == "grok-4.6":
            body["reasoning_effort"] = "low"
        try:
            async with asyncio.timeout(120), httpx.AsyncClient(timeout=115) as client:
                async with client.stream("POST", "https://nedolinko-0140-resource.services.ai.azure.com/openai/v1/chat/completions", headers={"api-key": os.environ["AZURE_API_KEY"]}, json=body) as response:
                    if response.status_code != 200:
                        return {"model": model, "status": response.status_code, "detail": (await response.aread()).decode()[:400]}
                    async for line in response.aiter_lines():
                        if not line.startswith("data:") or line[5:].strip() == "[DONE]":
                            continue
                        chunk = json.loads(line[5:].strip())
                        usage = chunk.get("usage") or usage
                        for choice in chunk.get("choices", []):
                            content = choice.get("delta", {}).get("content") or ""
                            if content and first is None:
                                first = time.monotonic() - start
                            text += content
                            finish = choice.get("finish_reason") or finish
            parsed = Batch.model_validate_json(text)
            assert [q.id for q in parsed.questions] == numbers and finish == "stop"
            return {"model": model, "status": 200, "seconds": round(time.monotonic() - start, 2), "first_content_seconds": round(first or 0, 2), "valid_questions": len(parsed.questions), "usage": usage}
        except Exception as error:
            return {"model": model, "seconds": round(time.monotonic() - start, 2), "error": type(error).__name__ + ": " + str(error)[:300]}

    print(json.dumps(await asyncio.gather(run("DeepSeek-V4-Flash"), run("grok-4.6")), indent=2), flush=True)


if __name__ == "__main__":
    asyncio.run(main())
