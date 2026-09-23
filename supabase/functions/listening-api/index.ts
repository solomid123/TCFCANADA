import { createClient } from "@supabase/supabase-js";

declare const EdgeRuntime: { waitUntil(promise: Promise<unknown>): void };
const project = Deno.env.get("SUPABASE_URL")!;
const admin = createClient(project, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
const bucket = "tcf-listening-private";
const table = "tcf_listening_sessions";
const seedID = "50f71ba1-5c93-4de7-b043-cf2c215fa4c6";
const letters = ["A", "B", "C", "D"];
type Turn = { speaker: "female" | "male"; text: string };
type Question = { id: number; kind: string; level: string; question: string; turns: Turn[]; options: string[]; correct_index: number; explanation: string; image_prompt: string | null };
type Asset = { name: string; path: string; sha256: string; bytes: number; duration?: number };
type Session = { id: string; owner_id: string | null; state: string; phase: string; planned: number; images: number; audio: number; plan: Question[]; assets: Record<string, Asset>; image_checks: Record<string, boolean>; image_attempts: Record<string, number>; error: string | null; lease_token: string | null; last_answers: Record<string, number> | null; last_score: number | null; completed_at: string | null };
const headers = { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-worker-secret", "Access-Control-Allow-Methods": "GET, POST, OPTIONS" };
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers });
const status = (s: Session) => ({ id: s.id, state: s.state, phase: s.phase, planned: s.planned, images: s.images, audio: s.audio, total: 39, error: s.error });
const publicAsset = (a: Asset) => ({ name: a.name, sha256: a.sha256, bytes: a.bytes });

function manifest(s: Session) {
  return { id: s.id, title: "Test d'écoute", questions: s.plan.map(q => ({
    id: q.id, kind: q.kind, level: q.level, question: q.question,
    options: ["picture", "response"].includes(q.kind) ? letters : q.options,
    audio: publicAsset(s.assets[`audio-${q.id}.wav`]),
    image: q.kind === "picture" ? publicAsset(s.assets[`image-${q.id}.png`]) : null,
    duration: s.assets[`audio-${q.id}.wav`].duration ?? 0,
  })) };
}

function transcript(q: Question) {
  return [...q.turns.map(t => t.text), ...(["picture", "response"].includes(q.kind) ? q.options.map((o, i) => `${letters[i]}. ${o}`) : [q.question])].join("\n\n");
}

function grade(s: Session, answers: Record<string, number>) {
  return { correct: s.plan.filter(q => answers[q.id] === q.correct_index).length, total: 39, answered: Object.keys(answers).length,
    questions: s.plan.map(q => ({ id: q.id, options: q.options, correct_index: q.correct_index, explanation: q.explanation, transcript: transcript(q) })) };
}

async function kick() {
  try {
    const response = await fetch(`${project}/functions/v1/listening-api/internal/worker`, {
      method: "POST", headers: { "x-worker-secret": Deno.env.get("TCF_WORKER_SECRET")! }, signal: AbortSignal.timeout(8000),
    });
    await response.body?.cancel();
  } catch { /* Scheduled database trigger resumes queued jobs if this handoff fails. */ }
}

async function provider(url: string, init: RequestInit) {
  const response = await fetch(url, { ...init, signal: AbortSignal.timeout(90000) });
  if (!response.ok) throw new Error(`Service de génération indisponible (HTTP ${response.status}). Réessayez.`);
  return response;
}

async function chat(messages: unknown[], maxTokens: number): Promise<Record<string, unknown>> {
  const response = await provider("https://nedolinko-0140-resource.services.ai.azure.com/openai/v1/chat/completions", {
    method: "POST", headers: { "api-key": Deno.env.get("AZURE_API_KEY")!, "Content-Type": "application/json" },
    body: JSON.stringify({ model: "grok-4.6", messages, reasoning_effort: "low", max_tokens: maxTokens, response_format: { type: "json_object" }, stream: true }),
  });
  let content = "";
  let finish: string | undefined;
  for (const line of (await response.text()).split("\n")) {
    if (!line.startsWith("data:")) continue;
    const raw = line.slice(5).trim();
    if (raw === "[DONE]") continue;
    const event = JSON.parse(raw);
    for (const choice of event.choices ?? []) {
      if (choice.index === 0) { content += choice.delta?.content ?? ""; finish = choice.finish_reason ?? finish; }
    }
  }
  if (finish !== "stop") throw new Error("La génération est incomplète. Réessayez pour reprendre la session.");
  return JSON.parse(content);
}

function blueprint(id: number) {
  return { id, kind: id <= 4 ? "picture" : id <= 10 ? "response" : id <= 23 ? "dialogue" : "report", level: id <= 4 ? "A1" : id <= 10 ? "A2" : id <= 19 ? "B1" : id <= 29 ? "B2" : id <= 36 ? "C1" : "C2" };
}

function validate(q: Question, id: number) {
  const b = blueprint(id);
  if (q.id !== id || q.kind !== b.kind || q.level !== b.level || !q.question || q.question.length > 350 ||
      !Array.isArray(q.options) || q.options.length !== 4 || q.options.some(o => typeof o !== "string" || !o.trim() || o.length > 350) ||
      new Set(q.options.map(o => o.trim().toLocaleLowerCase())).size !== 4 || !Number.isInteger(q.correct_index) || q.correct_index < 0 || q.correct_index > 3 ||
      !q.explanation || !Array.isArray(q.turns) || q.turns.length < 1 || q.turns.length > 8 ||
      q.turns.some(t => !["female", "male"].includes(t.speaker) || typeof t.text !== "string" || !t.text.trim()) ||
      q.turns.map(t => t.text).join(" ").split(/\s+/).length > 260 || (q.kind === "picture") !== !!q.image_prompt) {
    throw new Error("Une question ne respecte pas le format attendu. Réessayez pour la remplacer.");
  }
}

async function draft(s: Session): Promise<Question[]> {
  const numbers = Array.from({ length: Math.min(3, 39 - s.plan.length) }, (_, i) => s.plan.length + i + 1);
  const result = await chat([
    { role: "system", content: `Write original French listening practice, never official TCF material. JSON only {"questions":[...]}, exactly the supplied ids/kinds/levels. Each question has EXACT fields: id, kind, level, question (French), turns ([{speaker:"female"|"male",text:French}]), options (4 distinct French strings, no A/B/C/D prefixes), correct_index (integer 0..3), explanation (French, under 70 words), image_prompt (English or null). One unambiguously correct answer. Explanations quote wording, NEVER option letters or positions. Natural Canadian French, varied topics. No answer keys or stage directions in turns.
picture: one clearly described image, no collage, no printed text/labels/logos. image_prompt describes the scene in English. Exactly one of the four short spoken descriptions fits the image; the others visibly contradict it. turns is just a neutral instruction, not a scene description. question="Quelle proposition correspond à l'image ?".
response: turns is a short spoken question/statement, options are four replies, only one appropriate. question="Choisissez la réponse qui convient.".
For picture/response the SERVER appends the four spoken propositions to the audio; do NOT put them in turns.
dialogue: 3–6 alternating female/male turns, 50–100 words total, question about the conversation, four written answers.
report: 1–2 turns, 90–160 words total; advanced items test implicit meaning, viewpoint, nuance or intent with clear evidence in the script. Four written answers. image_prompt MUST be null for non-picture questions. Avoid repeating previous topics.` },
    { role: "user", content: JSON.stringify({ blueprint: numbers.map(blueprint), previous_topics: s.plan.map(q => q.question), seed: s.id }) },
  ], 5000);
  const questions = result.questions as Question[];
  if (!Array.isArray(questions) || questions.length !== numbers.length) throw new Error("Le nombre de questions reçues est incorrect.");
  questions.forEach((q, i) => {
    validate(q, numbers[i]);
    // Shuffle once before audio synthesis; saved choices and answer keys stay aligned.
    const order = [0, 1, 2, 3];
    for (let j = 3; j > 0; j--) {
      const k = crypto.getRandomValues(new Uint32Array(1))[0] % (j + 1);
      [order[j], order[k]] = [order[k], order[j]];
    }
    q.correct_index = order.indexOf(q.correct_index);
    q.options = order.map(index => q.options[index]);
  });
  return questions;
}

const escapeXML = (s: string) => s.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;").replaceAll('"', "&quot;");
const base64 = (bytes: Uint8Array) => {
  let text = "";
  for (let i = 0; i < bytes.length; i += 8192) text += String.fromCharCode(...bytes.subarray(i, i + 8192));
  return btoa(text);
};

async function put(s: Session, name: string, data: Uint8Array, type: string, duration?: number): Promise<Asset> {
  const sha = [...new Uint8Array(await crypto.subtle.digest("SHA-256", Uint8Array.from(data).buffer))].map(b => b.toString(16).padStart(2, "0")).join("");
  const path = `${s.id}/${sha}/${name}`;
  const result = await admin.storage.from(bucket).upload(path, data, { contentType: type, upsert: true });
  if (result.error) throw new Error("Le téléchargement vers le stockage a échoué. Réessayez.");
  return { name, path, sha256: sha, bytes: data.length, ...(duration === undefined ? {} : { duration }) };
}

function wavDuration(data: Uint8Array): number {
  const text = (i: number, n: number) => new TextDecoder().decode(data.slice(i, i + n));
  if (text(0, 4) !== "RIFF" || text(8, 4) !== "WAVE") throw new Error("Enregistrement audio invalide.");
  const view = new DataView(data.buffer, data.byteOffset, data.byteLength);
  let rate = 0;
  let size = 0;
  for (let i = 12; i + 8 <= data.length;) {
    const length = view.getUint32(i + 4, true);
    if (i + 8 + length > data.length) throw new Error("Enregistrement audio incomplet.");
    if (text(i, 4) === "fmt " && length >= 16) rate = view.getUint32(i + 16, true);
    if (text(i, 4) === "data") size = length;
    i += 8 + length + length % 2;
  }
  if (!rate || size / rate < 0.2) throw new Error("Enregistrement audio vide.");
  return size / rate;
}

async function step(s: Session): Promise<Record<string, unknown>> {
  if (s.plan.length < 39) {
    const plan = [...s.plan, ...await draft(s)];
    return { plan, planned: plan.length, phase: "Création des questions" };
  }
  for (const q of s.plan.slice(0, 4)) {
    const name = `image-${q.id}.png`;
    if (!s.assets[name]) {
      const count = s.image_attempts[q.id] ?? 0;
      if (count >= 2) throw new Error("Une image est ambiguë. Réessayez pour la remplacer.");
      const response = await provider("https://nedolinko-0140-resource.services.ai.azure.com/providers/blackforestlabs/v1/flux-2-pro?api-version=preview", {
        method: "POST", headers: { Authorization: `Bearer ${Deno.env.get("AZURE_API_KEY")}`, "Content-Type": "application/json" },
        body: JSON.stringify({ model: "FLUX.2-pro", prompt: q.image_prompt, width: 1024, height: 1024, n: 1 }),
      });
      const payload = await response.json();
      const bytes = Uint8Array.from(atob(payload.data[0].b64_json), c => c.charCodeAt(0));
      const png = bytes[0] === 137 && bytes[1] === 80 && bytes[2] === 78 && bytes[3] === 71;
      const jpeg = bytes[0] === 255 && bytes[1] === 216;
      if (!png && !jpeg) throw new Error("Format d'image inattendu.");
      const asset = await put(s, png ? name : name.replace(".png", ".jpg"), bytes, png ? "image/png" : "image/jpeg");
      return { assets: { ...s.assets, [name]: asset }, image_attempts: { ...s.image_attempts, [q.id]: count + 1 }, phase: "Vérification des images" };
    }
    if (!s.image_checks[q.id]) {
      const { data, error } = await admin.storage.from(bucket).download(s.assets[name].path);
      if (error || !data) throw new Error("Image indisponible.");
      const result = await chat([
        { role: "system", content: 'Check a French picture exercise against the ACTUAL image. JSON {"valid":true|false,"matching_index":0|1|2|3|null}. Valid ONLY if exactly one proposition clearly matches visible evidence. Do not guess invisible facts.' },
        { role: "user", content: [{ type: "text", text: JSON.stringify(q.options) }, { type: "image_url", image_url: { url: `data:${s.assets[name].name.endsWith(".jpg") ? "image/jpeg" : "image/png"};base64,${base64(new Uint8Array(await data.arrayBuffer()))}`, detail: "low" } }] },
      ], 600);
      if (result.valid === true && result.matching_index === q.correct_index) {
        const checks = { ...s.image_checks, [q.id]: true };
        return { image_checks: checks, images: Object.values(checks).filter(Boolean).length, phase: "Création des images" };
      }
      const assets = { ...s.assets };
      delete assets[name];
      return { assets, phase: "Remplacement d'une image ambiguë" };
    }
  }
  for (const q of s.plan) {
    const name = `audio-${q.id}.wav`;
    if (s.assets[name]) continue;
    const voices = { female: "fr-CA-SylvieNeural", male: "fr-CA-ThierryNeural" };
    let speech = q.turns.map(t => `<voice name="${voices[t.speaker]}"><lang xml:lang="fr-CA">${escapeXML(t.text)}</lang><break time="450ms"/></voice>`).join("");
    const ending = ["picture", "response"].includes(q.kind) ? q.options.map((o, i) => `${letters[i]}. ${escapeXML(o)}<break time="900ms"/>`).join("") : escapeXML(q.question);
    speech += `<voice name="${voices.female}"><lang xml:lang="fr-CA">${ending}</lang></voice>`;
    const response = await provider("https://nedolinko-0140-resource.cognitiveservices.azure.com/tts/cognitiveservices/v1", {
      method: "POST", headers: { "Ocp-Apim-Subscription-Key": Deno.env.get("AZURE_API_KEY")!, "Content-Type": "application/ssml+xml", "X-Microsoft-OutputFormat": "riff-24khz-16bit-mono-pcm" },
      body: `<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="fr-CA">${speech}</speak>`,
    });
    const bytes = new Uint8Array(await response.arrayBuffer());
    const asset = await put(s, name, bytes, "audio/wav", wavDuration(bytes));
    const assets = { ...s.assets, [name]: asset };
    return { assets, audio: Object.keys(assets).filter(k => k.startsWith("audio-")).length, phase: "Préparation des voix canadiennes" };
  }
  return { state: "ready", phase: "Votre session est prête", error: null };
}

async function worker() {
  const claim = await admin.rpc("claim_tcf_listening_job");
  const s = claim.data?.[0] as Session | undefined;
  if (claim.error || !s) return;
  try {
    const patch = await step(s);
    const saved = await admin.from(table).update({ ...patch, lease_token: null, lease_until: null, step_attempts: 0, updated_at: new Date().toISOString() }).eq("id", s.id).eq("lease_token", s.lease_token!);
    if (saved.error) throw new Error("La sauvegarde de la session a échoué.");
    await kick();
  } catch (error) {
    const message = error instanceof Error && !/apikey|token|secret/i.test(error.message) ? error.message.slice(0, 240) : "Préparation interrompue. Réessayez.";
    await admin.from(table).update({ state: "failed", error: message, lease_token: null, lease_until: null, updated_at: new Date().toISOString() }).eq("id", s.id).eq("lease_token", s.lease_token!);
  }
}

Deno.serve(async req => {
  if (req.method === "OPTIONS") return new Response(null, { headers });
  const path = new URL(req.url).pathname.replace(/^.*\/listening-api/, "");
  try {
    if (path === "/health") {
      const seed = await admin.from(table).select("state").eq("id", seedID).maybeSingle();
      return json({ status: "ok", service: "tcf-listening", api_version: 1, seed_ready: seed.data?.state === "ready" });
    }
    if (path === "/internal/worker") {
      const expected = Deno.env.get("TCF_WORKER_SECRET");
      if (!expected || req.headers.get("x-worker-secret") !== expected) return json({ detail: "Unauthorized" }, 401);
      EdgeRuntime.waitUntil(worker());
      return json({ accepted: true }, 202);
    }
    const jwt = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
    if (!jwt) return json({ detail: "Session expirée. Réessayez." }, 401);
    const auth = await admin.auth.getUser(jwt);
    if (auth.error || !auth.data.user) return json({ detail: "Session expirée. Réessayez." }, 401);
    const owner = auth.data.user.id;
    if (path === "/v1/listening/sessions" && req.method === "GET") {
      const offset = Math.max(0, Number.parseInt(new URL(req.url).searchParams.get("offset") ?? "0", 10) || 0);
      const [saved, count] = await Promise.all([
        admin.from(table).select("id,state,phase,planned,created_at,completed_at,last_score").eq("owner_id", owner).order("created_at", { ascending: false }).range(offset, offset + 49),
        admin.rpc("count_tcf_bank_questions", { p_owner: owner }),
      ]);
      if (saved.error || count.error) throw new Error("Historique indisponible.");
      return json({ sessions: saved.data, bank_count: Number(count.data ?? 39), has_more: saved.data.length === 50 });
    }
    const match = path.match(/^\/v1\/listening\/sessions\/([a-f0-9-]{36})(?:\/(content|submit|assets|attempt)(?:\/([^/]+))?)?$/i);
    if (!match || !/^[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}$/i.test(match[1])) return json({ detail: "Not found" }, 404);
    const id = match[1].toLowerCase();
    const action = match[2];
    const existing = await admin.from(table).select("*").eq("id", id).maybeSingle();
    if (existing.error) throw new Error("Base de données indisponible.");
    let s = existing.data as Session | null;
    if (s && s.owner_id !== owner) return json({ detail: "Session introuvable." }, 404);
    if (!action && req.method === "POST") {
      if (!s) {
        const previous = await admin.from(table).select("id", { count: "exact", head: true }).eq("owner_id", owner);
        const recent = await admin.from(table).select("id", { count: "exact", head: true }).not("owner_id", "is", null).gte("created_at", new Date(Date.now() - 86400000).toISOString());
        if ((recent.count ?? 0) >= 20) return json({ detail: "Limite de nouvelles sessions atteinte pour aujourd'hui." }, 429);
        const seed = !previous.count ? await admin.from(table).select("*").eq("id", seedID).eq("state", "ready").maybeSingle() : { data: null };
        const source = seed.data as Session | null;
        const inserted = await admin.from(table).insert(source ? { id, owner_id: owner, state: "ready", phase: "Votre session est prête", planned: 39, images: 4, audio: 39, plan: source.plan, assets: source.assets, image_checks: source.image_checks } : { id, owner_id: owner }).select().single();
        if (inserted.error) {
          const duplicate = await admin.from(table).select("*").eq("id", id).eq("owner_id", owner).maybeSingle();
          if (!duplicate.data) throw new Error("Impossible de préparer la session.");
          s = duplicate.data;
        } else s = inserted.data;
      } else if (s.state === "failed" && new URL(req.url).searchParams.get("retry") === "true") {
        const updated = await admin.from(table).update({ state: "queued", error: null, image_attempts: {}, step_attempts: 0, lease_token: null, lease_until: null }).eq("id", id).select().single();
        if (updated.error) throw new Error("Impossible de reprendre la session.");
        s = updated.data;
      }
      if (s!.state !== "ready") EdgeRuntime.waitUntil(kick());
      return json(status(s!));
    }
    if (!s) return json({ detail: "Session introuvable." }, 404);
    if (!action && req.method === "GET") return json(status(s));
    if (s.state !== "ready") return json({ detail: "La session est encore en préparation." }, 409);
    if (action === "content" && req.method === "GET") return json(manifest(s));
    if (action === "attempt" && req.method === "GET") return json({ answers: s.last_answers ?? {}, result: s.last_answers ? grade(s, s.last_answers) : null });
    if (action === "assets" && req.method === "GET") {
      const asset = Object.values(s.assets).find(a => a.name === match[3]);
      if (!asset || !/^(audio-\d+\.wav|image-\d+\.(png|jpg))$/.test(match[3])) return json({ detail: "Not found" }, 404);
      const signed = await admin.storage.from(bucket).createSignedUrl(asset.path, 120);
      if (signed.error) throw new Error("Enregistrement temporairement indisponible.");
      return Response.redirect(signed.data.signedUrl, 302);
    }
    if (action === "submit" && req.method === "POST") {
      const body = await req.json();
      const answers = body.answers;
      if (!answers || Array.isArray(answers) || typeof answers !== "object" || Object.entries(answers).some(([key, value]) => !/^([1-9]|[12][0-9]|3[0-9])$/.test(key) || !Number.isInteger(value) || Number(value) < 0 || Number(value) > 3)) return json({ detail: "Réponses invalides." }, 422);
      const result = grade(s, answers);
      const saved = await admin.from(table).update({ last_answers: answers, last_score: result.correct, completed_at: new Date().toISOString() }).eq("id", id).eq("owner_id", owner);
      if (saved.error) throw new Error("Impossible de sauvegarder le bilan.");
      return json(result);
    }
    return json({ detail: "Not found" }, 404);
  } catch {
    return json({ detail: "Le service d'écoute est momentanément indisponible. Réessayez." }, 503);
  }
});
