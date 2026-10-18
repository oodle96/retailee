// Smoke test: confirms this machine/project can reach the configured Gemini
// model on Vertex AI. Run after `gcloud auth application-default login`:
//   npx tsx src/check-model.ts
import { GoogleGenAI } from '@google/genai';

const project = process.env.GOOGLE_CLOUD_PROJECT;
const location = process.env.GEMINI_LOCATION ?? 'global';
const model = process.env.GEMINI_MODEL ?? 'gemini-3.8-flash';

if (!project) {
  console.error('Set GOOGLE_CLOUD_PROJECT first.');
  process.exit(1);
}
const ai = new GoogleGenAI({ vertexai: true, project, location });
try {
  const res = await ai.models.generateContent({ model, contents: 'Balas dengan satu kata: siap' });
  console.log(`OK  project=${project} location=${location} model=${model} → ${res.text?.trim()}`);
} catch (e) {
  console.error(`FAILED  project=${project} location=${location} model=${model}`);
  console.error(String((e as Error).message ?? e));
  process.exit(1);
}
