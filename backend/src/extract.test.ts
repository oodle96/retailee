import request from 'supertest';
import { describe, expect, it } from 'vitest';

import { createApp } from './app.js';
import { FakeGemini, buildPrompt, type ModelClient } from './gemini.js';
import { normalize, parseAmount } from './normalize.js';
import { ExtractRequest } from './schema.js';

const IMG = 'A'.repeat(200); // fake base64 payload
const quiet = () => {};

function app(model: ModelClient = new FakeGemini(), rate = 50) {
  return createApp({ model, appKey: 'test-key', ratePerMinute: rate, log: quiet });
}

describe('parseAmount', () => {
  it.each([
    [3500, 3500],
    ['3.500', 3500],
    ['3rb', 3000],
    ['4 rb', 4000],
    ['2,5rb', 2500],
    ['Rp 50.000', 50000],
    ['4k', 4000],
    [null, null],
    ['abc', null],
  ])('%s → %s', (input, out) => expect(parseAmount(input)).toBe(out));
});

describe('normalize', () => {
  it('flags qty × price ≠ total instead of trusting it', () => {
    const r = normalize('dailySales', {
      rows: [{ raw_text: 'aqua 5 x 4000 = 25000', product_name: 'aqua', quantity: 5, unit_price: 4000, total: 25000, confidence: 0.95 }],
    });
    expect(r.rows[0].confidence).toBeLessThanOrEqual(0.6);
    expect(r.rows[0].notes.join(' ')).toContain('tidak sama');
  });

  it('derives unit price from total with lowered confidence', () => {
    const r = normalize('dailySales', {
      rows: [{ raw_text: 'indomie 10 = 35rb', product_name: 'indomie', quantity: 10, unit_price: null, total: '35rb', confidence: 0.9 }],
    });
    expect(r.rows[0].unitPrice).toBe(3500);
    expect(r.rows[0].confidence).toBeLessThanOrEqual(0.7);
  });

  it('keeps unknown cost as null, never 0', () => {
    const r = normalize('openingStock', {
      rows: [{ raw_text: 'gula 8', product_name: 'Gula', quantity: 8, unit_cost: null, unit_price: 16000, confidence: 0.6 }],
    });
    expect(r.rows[0].unitCost).toBeNull();
  });

  it('drops non-product lines and bad dates', () => {
    const r = normalize('dailySales', {
      date: '16/10/2026',
      rows: [
        { raw_text: 'TOTAL', product_name: '', quantity: null, confidence: 0.9 },
        { raw_text: 'teh 0', product_name: 'teh', quantity: 0, confidence: 0.9 },
      ],
    });
    expect(r.rows).toHaveLength(0);
    expect(r.date).toBeNull();
  });

  it('falls back to safe expense defaults', () => {
    const r = normalize('expenseReceipt', {
      rows: [],
      expense: { description: 'Bensin', amount: '25.000', category: 'Bensin', expense_type: 'weird', confidence: 90 },
    });
    expect(r.expense).toMatchObject({ amount: 25000, category: 'Lainnya', type: 'businessExpense', confidence: 0.9 });
  });
});

describe('POST /v1/extract', () => {
  it('rejects requests without the app key', async () => {
    const res = await request(app()).post('/v1/extract').send({ kind: 'dailySales', imageBase64: IMG });
    expect(res.status).toBe(401);
  });

  it('validates the request body', async () => {
    const res = await request(app()).post('/v1/extract').set('x-app-key', 'test-key').send({ kind: 'nope' });
    expect(res.status).toBe(400);
  });

  it('returns normalized PRD demo sales', async () => {
    const res = await request(app())
      .post('/v1/extract')
      .set('x-app-key', 'test-key')
      .send({ kind: 'dailySales', imageBase64: IMG, catalog: ['Indomie Goreng', 'Aqua 600ml', 'Teh Pucuk'] });
    expect(res.status).toBe(200);
    const total = res.body.rows.reduce((s: number, r: { qty: number; unitPrice: number }) => s + r.qty * r.unitPrice, 0);
    expect(total).toBe(75000);
    expect(res.body.rows.find((r: { name: string }) => r.name === 'Teh pcuk').confidence).toBeLessThan(0.75);
  });

  it('maps model failure to a friendly 502 (hybrid recovery)', async () => {
    const broken: ModelClient = { model: 'x', generate: async () => 'not json' };
    const res = await request(app(broken)).post('/v1/extract').set('x-app-key', 'test-key').send({ kind: 'dailySales', imageBase64: IMG });
    expect(res.status).toBe(502);
    expect(res.body.message).toContain('isi manual');
  });

  it('returns 422 when nothing readable was found', async () => {
    const empty: ModelClient = { model: 'x', generate: async () => JSON.stringify({ rows: [] }) };
    const res = await request(app(empty)).post('/v1/extract').set('x-app-key', 'test-key').send({ kind: 'dailySales', imageBase64: IMG });
    expect(res.status).toBe(422);
  });

  it('rate limits per client', async () => {
    const a = app(new FakeGemini(), 2);
    const send = () =>
      request(a).post('/v1/extract').set('x-app-key', 'test-key').set('x-client-id', 'c1').send({ kind: 'expenseReceipt', imageBase64: IMG });
    expect((await send()).status).toBe(200);
    expect((await send()).status).toBe(200);
    expect((await send()).status).toBe(429);
  });
});

describe('prompt', () => {
  it('includes the catalog and retry hint', () => {
    const p = buildPrompt(ExtractRequest.parse({ kind: 'dailySales', imageBase64: IMG, catalog: ['Teh Pucuk'], attempt: 2 }));
    expect(p).toContain('Teh Pucuk');
    expect(p).toContain('pembacaan ulang');
  });
});
