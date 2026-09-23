import { speechSSML, spokenTranscript } from "./audio.ts";

Deno.test("spoken propositions have a lead-in, announced labels and deliberate pauses", () => {
  const q = { kind: "picture", question: "Choisissez.", turns: [{ speaker: "female" as const, text: "Écoutez & choisissez." }], options: ["Un chat.", "Un vélo.", "Un train.", "Un livre."] };
  const ssml = speechSSML(q);
  if (!ssml.includes('<break time="900ms"/>Écoutez &amp; choisissez.')) throw new Error("Missing lead-in or XML escaping");
  for (const [i, letter] of ["A", "B", "C", "D"].entries()) {
    if (!ssml.includes(`Proposition ${letter}.<break time="700ms"/>${q.options[i]}<break time="1500ms"/>`)) throw new Error("Missing proposition pacing");
  }
  if (!spokenTranscript(q).includes("Proposition A. Un chat.")) throw new Error("Transcript and audio labels differ");
});

Deno.test("dialogues retain separate voices and do not read written answer choices", () => {
  const q = { kind: "dialogue", question: "À quelle heure ?", turns: [{ speaker: "female" as const, text: "Bonjour." }, { speaker: "male" as const, text: "À midi." }], options: ["Un.", "Deux.", "Trois.", "Quatre."] };
  const ssml = speechSSML(q);
  if (!ssml.includes("fr-CA-SylvieNeural") || !ssml.includes("fr-CA-ThierryNeural")) throw new Error("Dialogue voices missing");
  if (ssml.includes("Proposition") || ssml.includes("Quatre.")) throw new Error("Written choices leaked into dialogue audio");
});
