# Hosted listening service

Project: `dpjrxzxidlpfzidqqllp`.

Public API: `https://dpjrxzxidlpfzidqqllp.supabase.co/functions/v1/listening-api`.

## App connection

The release app reads `CloudConfiguration.plist`, creates an anonymous Supabase Auth session, and refreshes its token automatically. The publishable key is public configuration. The app never receives the Azure key, service-role key, personal deployment tokens or internal worker secret.

Every session API request validates the user's JWT through Supabase Auth and checks the session's owner. Tables have RLS enabled and direct access revoked from anonymous/authenticated clients. Media stays in the private `tcf-listening-private` bucket and is delivered using short-lived signed links after ownership checks.

The initial session is cloned from a prepared seed, sharing its immutable media. Reopening a session and reviewing answers do not call Azure again. Selecting a new series creates a queued generation job.

## Saved tests

`GET /v1/listening/sessions?offset=0` lists the authenticated owner's prepared and completed tests, in pages of 50. It includes a deduplicated count of questions in that user's ready tests and starter set. Submission persists answers, score and completion date. `GET /v1/listening/sessions/{id}/attempt` restores the owner's saved answers and full correction. No answer keys are included in the practice manifest or history list.

Run `backend/.venv/bin/python scripts/check-saved-tests.py` to verify persistence, score restoration and cross-owner isolation without generating paid content. The `testCompletedListeningTestReopensFromQuestionBank` UI test completes a test, reopens its result from Mes tests and repeats after app relaunch.

## Background jobs

The `claim_tcf_listening_job` database function serializes claims and grants a short lease. Each Edge Function invocation handles one small checkpoint: three questions, one image, one image validation, one audio file, or final publication. Completed plan/media metadata are persisted immediately. Expired leases have bounded retries; user-requested retries preserve completed work.

The worker hands off to the next invocation, with a database cron trigger as a recovery path. Its internal endpoint requires a secret available only in Edge Function secrets and Supabase Vault. The backend is independent of the developer Mac.

The initial 39-item dataset is AI-authored training content, not an official calibrated exam. New series follow the app's 4-picture / 6-response / 13-dialogue / 16-report training blueprint.

## Deploy

Put `SUPABASE_ACCESS_TOKEN`, `SUPABASE_SECRET_KEY`, `SUPABASE_PROJECT_REF`, `SUPABASE_URL`, and `AZURE_API_KEY` in the ignored `backend/.env`. Install the Supabase CLI, then run:

```sh
backend/.venv/bin/python scripts/deploy-cloud.py
```

This applies the schema, enables anonymous device authentication, sets function secrets, uploads the existing seed media, deploys the function and configures the recovery trigger. For function-only updates, load the deployment token into the environment and run:

```sh
supabase functions deploy listening-api --project-ref dpjrxzxidlpfzidqqllp --no-verify-jwt --use-api
```

Gateway JWT verification is disabled because the function explicitly validates bearer user tokens itself; this also permits the separately authenticated internal worker endpoint.

## Verify

```sh
deno check --config supabase/functions/listening-api/deno.json supabase/functions/listening-api/index.ts
python3 scripts/check-cloud.py
backend/.venv/bin/python scripts/check-hosted-listening.py
```

The hosted check signs in through the public API, downloads and checksums all 43 media files, verifies private-seed access protection, refreshes authentication and checks grading. Set `CHECK_CLOUD_WORKER=1` to additionally regenerate one final question/audio pair as a live, low-cost worker check.

The `testHostedAutomaticConnectionWithoutServerSettings` UI test exercises automatic connection and relaunch. Run it with the Release configuration to also verify that the server-settings button is absent.
