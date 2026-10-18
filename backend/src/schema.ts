import { z } from 'zod';
import { BusinessContext } from './personalization.js';

/** Document kinds — must match the app's `DocKind` enum names. */
export const DocKind = z.enum(['openingStock', 'dailySales', 'expenseReceipt', 'serviceIncome']);
export type DocKind = z.infer<typeof DocKind>;

export const EXPENSE_CATEGORIES = [
  'Sewa',
  'Listrik & air',
  'Gaji',
  'Transportasi',
  'Pemasaran',
  'Pulsa & internet',
  'Perlengkapan',
  'Perawatan',
  'Lainnya',
] as const;

export const ExpenseType = z.enum(['businessExpense', 'personalWithdrawal', 'inventoryPurchase']);

/** Request from the app. The image is base64 (no data: prefix). */
export const ExtractRequest = z.object({
  kind: DocKind,
  imageBase64: z.string().min(100, 'image missing'),
  mimeType: z.enum(['image/jpeg', 'image/png', 'image/webp', 'image/heic']).default('image/jpeg'),
  catalog: z.array(z.string().max(80)).max(500).default([]),
  attempt: z.number().int().min(1).max(10).default(1),
  business: BusinessContext.optional(),
});
export type ExtractRequest = z.infer<typeof ExtractRequest>;

// ---------------------------------------------------------------- model output
// Lenient on purpose: the model may omit fields; normalization fills gaps and
// lowers confidence instead of failing the whole document.
const num = z.union([z.number(), z.string()]).nullish();

export const ModelRow = z.object({
  unit: z.string().max(32).nullish(),
  raw_text: z.string().default(''),
  product_name: z.string().default(''),
  quantity: num,
  unit_price: num,
  unit_cost: num,
  total: num,
  confidence: num,
});

export const ModelOutput = z.object({
  date: z.string().nullish(),
  rows: z.array(ModelRow).default([]),
  expense: z
    .object({
      description: z.string().default(''),
      amount: num,
      vendor: z.string().nullish(),
      category: z.string().nullish(),
      expense_type: z.string().nullish(),
      confidence: num,
    })
    .nullish(),
});
export type ModelOutput = z.infer<typeof ModelOutput>;

// ------------------------------------------------------------- API response
export interface OutRow {
  unit?: string;
  rawText: string;
  name: string;
  qty: number;
  unitPrice: number | null;
  unitCost: number | null;
  total: number | null;
  confidence: number;
  notes: string[];
}

export interface OutExpense {
  description: string;
  amount: number;
  vendor: string | null;
  category: string;
  type: z.infer<typeof ExpenseType>;
  confidence: number;
  notes: string[];
}

export interface ExtractResponse {
  kind: DocKind;
  date: string | null; // YYYY-MM-DD
  rows: OutRow[];
  expense: OutExpense | null;
  model: string;
  latencyMs: number;
}

/** JSON schema handed to Gemini's structured output. */
export function responseJsonSchema(kind: DocKind): object {
  const nullableNumber = { type: ['number', 'null'] };
  if (kind === 'expenseReceipt') {
    return {
      type: 'object',
      properties: {
        date: { type: ['string', 'null'], description: 'YYYY-MM-DD if printed on the receipt' },
        expense: {
          type: 'object',
          properties: {
            description: { type: 'string' },
            amount: { type: 'number', description: 'Total paid in rupiah, plain integer' },
            vendor: { type: ['string', 'null'] },
            category: { type: 'string', enum: [...EXPENSE_CATEGORIES] },
            expense_type: { type: 'string', enum: ExpenseType.options },
            confidence: { type: 'number' },
          },
          required: ['description', 'amount', 'category', 'expense_type', 'confidence'],
        },
      },
      required: ['expense'],
    };
  }
  const row: Record<string, unknown> = {
    unit: { type: ['string', 'null'], description: 'Unit exactly as written, e.g. pcs, pack, pasang or kg; preserve each product unit, never convert; null if unknown' },
    raw_text: { type: 'string', description: 'The line exactly as written, verbatim' },
    product_name: { type: 'string', description: 'Product name as written, lightly cleaned' },
    quantity: { type: 'number' },
    confidence: { type: 'number', description: '0..1, how sure you are this line was read correctly' },
  };
  if (kind === 'dailySales' || kind === 'serviceIncome') {
    row.unit_price = { ...nullableNumber, description: 'Price per unit in rupiah' };
    row.total = { ...nullableNumber, description: 'Line total in rupiah if written' };
    if (kind === 'serviceIncome') row.unit_cost = { ...nullableNumber, description: 'Explicit direct cost per service unit, null if unknown' };
  } else {
    row.unit_cost = { ...nullableNumber, description: 'Purchase cost (modal) per unit; null if not written' };
    row.unit_price = { ...nullableNumber, description: 'Selling price (jual) per unit; null if not written' };
  }
  return {
    type: 'object',
    properties: {
      date: { type: ['string', 'null'], description: 'YYYY-MM-DD if a date is written' },
      rows: {
        type: 'array',
        items: { type: 'object', properties: row, required: ['raw_text', 'product_name', 'quantity', 'confidence'] },
      },
    },
    required: ['rows'],
  };
}
