export const AUDIO_VERSION = 2;

export type SpeechQuestion = {
  kind: string;
  question: string;
  turns: { speaker: "female" | "male"; text: string }[];
  options: string[];
};

const letters = ["A", "B", "C", "D"];
const escapeXML = (s: string) => s.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;").replaceAll('"', "&quot;");

export function speechSSML(q: SpeechQuestion): string {
  const voices = { female: "fr-CA-SylvieNeural", male: "fr-CA-ThierryNeural" };
  const turns = q.turns.map((turn, index) =>
    `<voice name="${voices[turn.speaker]}"><lang xml:lang="fr-CA">${index === 0 ? '<break time="900ms"/>' : ""}${escapeXML(turn.text)}</lang><break time="600ms"/></voice>`
  ).join("");
  const ending = ["picture", "response"].includes(q.kind)
    ? q.options.map((option, index) => `Proposition ${letters[index]}.<break time="700ms"/>${escapeXML(option)}<break time="1500ms"/>`).join("")
    : escapeXML(q.question);
  return `<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="fr-CA">${turns}<voice name="${voices.female}"><lang xml:lang="fr-CA"><break time="900ms"/>${ending}</lang></voice></speak>`;
}

export function spokenTranscript(q: SpeechQuestion): string {
  return [...q.turns.map(t => t.text), ...(["picture", "response"].includes(q.kind)
    ? q.options.map((option, index) => `Proposition ${letters[index]}. ${option}`)
    : [q.question])].join("\n\n");
}
