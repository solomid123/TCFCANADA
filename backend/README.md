# AI listening backend

Python 3.11+ service for the app's **Écoute → Session IA · 39 questions** flow.

## Run locally

```sh
cd backend
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
cp .env.example .env
```

Fill in `.env`:

- `AZURE_API_KEY`: the Azure resource key. The configured `grok-4.6` endpoint accepts API-key authentication; `azure.identity` is not needed for this setup.
- `TCF_API_TOKEN`: a separate random access token for this backend. Generate one with `python3 -c 'import secrets; print(secrets.token_urlsafe(32))'`.
- `AZURE_SPEECH_KEY`: only needed if Speech has a different key.

The example includes the supplied Grok, FLUX and Speech endpoint URLs. Credentials are read from environment variables or the ignored `.env` file; Azure credentials are never sent to the app.

Start one worker:

```sh
.venv/bin/python -m uvicorn app:app --host 127.0.0.1 --port 8765
```

In the iPhone simulator, open **Écoute → Session IA → Connexion**, use `http://127.0.0.1:8765`, and enter `TCF_API_TOKEN`. The backend token is saved in Keychain. For a physical iPhone, host this service behind HTTPS and enter that reachable URL. Keep `data/` on a persistent volume. The in-process generation queue is designed for a single backend worker.

## Generation and cost controls

- Three resumable text batches of 13 questions, using `grok-4.6` with low reasoning effort to reduce reasoning-token overhead.
- Four FLUX images, only for the four picture exercises. A Grok vision check compares the actual generated image against the answer choices; ambiguous images are retried at most once.
- 39 cached audio recordings, with Canadian French Sylvie/Thierry voices and speaker changes for dialogues.
- Standard `fr-CA-SylvieNeural` / `fr-CA-ThierryNeural` voices by default. To use HD, set the voice variables to `fr-CA-Sylvie:DragonHDLatestNeural` and `fr-CA-Thierry:DragonHDLatestNeural`.
- One generation job at a time, two concurrent audio requests, bounded retries, and a configurable daily new-session limit (default 8).
- Read timeouts are not silently retried: a timed-out provider call may already have been billed.
- Reopening a session reuses its ID and media. A retry retains completed text batches, verified images and valid audio files. Only **Générer une nouvelle série** creates a new session.
- Provider-reported token usage is recorded in the session's `usage.json`. Actual charges depend on the Azure deployments and pricing; there is no hard-coded price estimate.

The training blueprint uses 4 picture questions, 6 spoken-response questions, 13 dialogues, and 16 reports, with progressive A1–C2 difficulty. This is an app-specific training distribution, not a claim about the official question distribution. Audio duration varies with generated content; practice is self-paced.

Structural validation checks question IDs, levels, four distinct options, answer indices, speaker roles, word budgets and image requirements. Image checks add visual verification; generated language and answer reasoning are still AI-authored, not professionally calibrated exam items.

## API

All `/v1` routes require `Authorization: Bearer <TCF_API_TOKEN>`.

| Method | Route | Purpose |
| --- | --- | --- |
| GET | `/health` | Process health |
| POST | `/v1/listening/sessions/{uuid}` | Idempotent prepare/resume |
| POST | `/v1/listening/sessions/{uuid}?retry=true` | Retry a failed job |
| GET | `/v1/listening/sessions/{uuid}` | Progress / failure details |
| GET | `/v1/listening/sessions/{uuid}/content` | Ready session manifest |
| GET | `/v1/listening/sessions/{uuid}/assets/{name}` | Authenticated audio/image download |
| POST | `/v1/listening/sessions/{uuid}/submit` | Grade answers and return all 39 corrections |

Submission body: `{"answers":{"1":0,"2":2}}`. Question IDs are 1–39; answer indices are 0–3. Unanswered questions are counted as incorrect.

The practice manifest omits answer keys, transcripts and explanations. Spoken-choice questions expose only A/B/C/D until submission. The app checks media SHA-256 hashes, caches the complete session, saves answers and restores progress after relaunch. Final grading requires connectivity; a downloaded review can be read offline.

## Checks

Offline backend checks (no Azure calls):

```sh
.venv/bin/python -m unittest discover -s tests -v
```

Start the deterministic server for the iOS UI integration test:

```sh
.venv/bin/python -m tests.fixture_server
```

Then run the `apptsst` Xcode scheme's tests. The additional AI test uses port 8766 and a test-only token, downloads 39 fixture recordings, verifies hidden propositions, answers all questions, checks resume after relaunch, and opens the final review. It is skipped if the fixture server is unavailable.

Opt-in live check (creates paid media once; reuse the same UUID on later runs):

```sh
TCF_API_TOKEN=<backend-token> .venv/bin/python live_check.py <session-uuid>
```

## Stored state

Each `data/{uuid}/` directory contains generation status, validated batches, images, WAV files, a public manifest and a private review file. Writes are atomic. Incomplete jobs are marked interrupted on server restart and resume when the app reconnects. Raw provider error bodies and credentials are not exposed to clients.
