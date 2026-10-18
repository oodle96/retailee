import { createApp } from './app.js';
import { FakeGemini, VertexGemini, type ModelClient } from './gemini.js';
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

const port = Number(process.env.PORT ?? 8080);
const appKey = process.env.APP_KEY ?? '';
const firebaseProject = process.env.FIREBASE_PROJECT_ID ?? '';
const legacyAuth = process.env.ALLOW_LEGACY_APP_KEY === '1' || process.env.GEMINI_FAKE === '1';
if (!firebaseProject && !(legacyAuth && appKey)) {
  console.error('Set FIREBASE_PROJECT_ID for Google login, or explicitly enable legacy local development auth.');
  process.exit(1);
}
if (firebaseProject) initializeApp({ projectId: firebaseProject });

let model: ModelClient;
if (process.env.GEMINI_FAKE === '1') {
  model = new FakeGemini();
} else {
  // On Cloud Run the project is detected automatically from the metadata server.
  const project = process.env.GOOGLE_CLOUD_PROJECT || undefined;
  const location = process.env.GEMINI_LOCATION ?? 'global';
  model = new VertexGemini(process.env.GEMINI_MODEL ?? 'gemini-3.8-flash', project, location);
}

createApp({
  model,
  appKey: legacyAuth ? appKey : undefined,
  verifyToken: firebaseProject ? async (token) => getAuth().verifyIdToken(token) : undefined,
  allowedOrigins: (process.env.ALLOWED_ORIGINS ?? '').split(',').map((s) => s.trim()).filter(Boolean),
  ratePerMinute: Number(process.env.RATE_PER_MINUTE ?? 20),
}).listen(port, () => {
  console.log(JSON.stringify({ event: 'listening', port, model: model.model }));
});
