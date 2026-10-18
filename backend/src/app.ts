import express, { type NextFunction, type Request, type Response } from 'express';
import { timingSafeEqual } from 'node:crypto';

import type { ModelClient } from './gemini.js';
import { normalize } from './normalize.js';
import { ExtractRequest, ModelOutput, type ExtractResponse } from './schema.js';
import { PersonalizeRequest, validateAdvice } from './personalization.js';
import { UnderstandRequest, Understanding } from './business-understanding.js';

export interface AppOptions {
  model: ModelClient;
  /** Shared key for explicitly enabled legacy local development only. */
  appKey?: string;
  verifyToken?: (token: string) => Promise<{ uid: string }>;
  allowedOrigins?: string[];
  /** Max extractions per client per minute. */
  ratePerMinute?: number;
  log?: (entry: Record<string, unknown>) => void;
}

function safeEqual(a: string, b: string): boolean {
  const x = Buffer.from(a);
  const y = Buffer.from(b);
  return x.length === y.length && timingSafeEqual(x, y);
}

export function createApp(opts: AppOptions) {
  const app = express();
  const log = opts.log ?? ((e) => console.log(JSON.stringify(e)));
  const rate = opts.ratePerMinute ?? 20;
  const hits = new Map<string, number[]>();

  app.disable('x-powered-by');
  app.use((req, res, next) => {
    const origin = req.header('origin');
    if (origin) {
      res.vary('Origin');
      if (!opts.allowedOrigins?.includes(origin)) {
        res.status(403).json({ error: 'origin_denied', message: 'Alamat aplikasi belum diizinkan.' });
        return;
      }
      res.setHeader('Access-Control-Allow-Origin', origin);
      res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-App-Key, X-Client-Id');
      res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    }
    if (req.method === 'OPTIONS') { res.sendStatus(204); return; }
    next();
  });
  app.use(express.json({ limit: '10mb' }));

  app.get(['/health', '/healthz'], (_req, res) => {
    res.json({ ok: true, model: opts.model.model });
  });

  const auth = async (req: Request, res: Response, next: NextFunction) => {
    if (opts.verifyToken) {
      const header = req.header('authorization') ?? '';
      try {
        if (!header.startsWith('Bearer ')) throw new Error('missing token');
        const user = await opts.verifyToken(header.slice(7));
        if (!user.uid) throw new Error('missing uid');
        res.locals.uid = user.uid;
        next();
      } catch {
        res.status(401).json({ error: 'unauthorized', message: 'Sesi Google berakhir. Masuk kembali.' });
      }
      return;
    }
    const key = req.header('x-app-key') ?? '';
    if (!opts.appKey || !safeEqual(key, opts.appKey)) {
      res.status(401).json({ error: 'unauthorized', message: 'Akses ditolak.' });
      return;
    }
    next();
  };

  const limiter = (req: Request, res: Response, next: NextFunction) => {
    const id = res.locals.uid || req.ip || 'anon';
    const now = Date.now();
    for (const [key, timestamps] of hits) {
      if (timestamps.every((t) => now - t >= 60_000)) hits.delete(key);
    }
    const recent = (hits.get(id) ?? []).filter((t) => now - t < 60_000);
    if (recent.length >= rate) {
      res.status(429).json({ error: 'rate_limited', message: 'Terlalu banyak permintaan. Coba lagi sebentar.' });
      return;
    }
    recent.push(now);
    hits.set(id, recent);
    next();
  };

  /**
   * POST /v1/extract — reads a photo into a DRAFT. Never posts anything:
   * the app shows the result for mandatory review (PRD §5).
   */
  app.post('/v1/extract', auth, limiter, async (req, res) => {
    const started = Date.now();
    const parsed = ExtractRequest.safeParse(req.body);
    if (!parsed.success) {
      res.status(400).json({ error: 'bad_request', message: 'Permintaan tidak valid.', issues: parsed.error.issues });
      return;
    }
    const body = parsed.data;
    try {
      const raw = await opts.model.generate(body);
      let json: unknown;
      try {
        json = JSON.parse(raw);
      } catch {
        throw new Error('model returned non-JSON');
      }
      const out = ModelOutput.safeParse(json);
      if (!out.success) throw new Error('model output failed schema');
      const norm = normalize(body.kind, out.data);
      if (norm.rows.length === 0 && !norm.expense) {
        res.status(422).json({
          error: 'nothing_found',
          message: 'Tidak ada catatan yang terbaca. Coba foto ulang lebih dekat dengan cahaya cukup.',
        });
        return;
      }
      const response: ExtractResponse = {
        kind: body.kind,
        ...norm,
        model: opts.model.model,
        latencyMs: Date.now() - started,
      };
      // Minimal logging: no image, no line contents (PRD §15).
      log({ event: 'extract_ok', kind: body.kind, rows: norm.rows.length, ms: response.latencyMs, attempt: body.attempt });
      res.json(response);
    } catch (e) {
      log({ event: 'extract_error', kind: body.kind, ms: Date.now() - started });
      res.status(502).json({
        error: 'extraction_failed',
        message: 'AI belum bisa membaca foto ini. Coba proses ulang, foto ulang, atau isi manual.',
      });
    }
  });

  app.post('/v1/personalize', auth, limiter, async (req, res) => {
    const parsed = PersonalizeRequest.safeParse(req.body);
    if (!parsed.success) { res.status(400).json({ error: 'bad_context', message: 'Konteks usaha belum lengkap.' }); return; }
    if (!opts.model.personalize) { res.status(503).json({ error: 'unavailable', message: 'Personalisasi Gemini tidak tersedia pada server demo.' }); return; }
    try {
      const raw = await opts.model.personalize(parsed.data);
      res.json(validateAdvice(raw, parsed.data, opts.model.model));
      log({ event: 'personalize_ok', businessType: parsed.data.business.type });
    } catch {
      log({ event: 'personalize_error' });
      res.status(502).json({ error: 'advice_failed', message: 'Saran Gemini belum tersedia. Catatan usahamu tetap aman. Coba lagi.' });
    }
  });

  app.post('/v1/business-understanding', auth, limiter, async (req, res) => {
    const parsed = UnderstandRequest.safeParse(req.body);
    if (!parsed.success) { res.status(400).json({ message: 'Profil usaha tidak valid.' }); return; }
    if (!opts.model.understand) { res.status(503).json({ message: 'Pemahaman Gemini tidak tersedia di demo lokal.' }); return; }
    try {
      const understanding = Understanding.parse(JSON.parse(await opts.model.understand(parsed.data)));
      const activities = [...new Set(understanding.activities)];
      const service = activities.includes('services');
      res.json({ ...understanding, activities, mode: service ? activities.length > 1 ? 'mixed' : 'services' : 'goods', model: opts.model.model });
    } catch {
      log({ event: 'business_understanding_error' });
      res.status(502).json({ message: 'Gemini belum dapat memahami usaha. Coba lagi.' });
    }
  });

  app.use((err: { type?: string }, _req: Request, res: Response, _next: NextFunction) => {
    const tooLarge = err.type === 'entity.too.large';
    res.status(tooLarge ? 413 : 400).json({
      error: tooLarge ? 'image_too_large' : 'bad_request',
      message: tooLarge ? 'Foto terlalu besar. Pilih foto yang lebih kecil.' : 'Permintaan tidak valid.',
    });
  });

  return app;
}
