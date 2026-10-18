import {
  EXPENSE_CATEGORIES,
  ExpenseType,
  type DocKind,
  type ModelOutput,
  type OutExpense,
  type OutRow,
} from './schema.js';

/**
 * Parses rupiah-ish values the model may return as strings:
 * "3.500", "3,500", "3rb", "4 rb", "Rp 50.000", "2,5rb", 3500.
 */
export function parseAmount(v: unknown): number | null {
  if (v === null || v === undefined) return null;
  if (typeof v === 'number') return Number.isFinite(v) ? v : null;
  let t = String(v).trim().toLowerCase().replace(/rp\.?/g, '').replace(/\s+/g, '');
  if (!t) return null;
  const thousands = /(rb|ribu|k)$/.test(t);
  if (thousands) {
    t = t.replace(/(rb|ribu|k)$/, '').replace(',', '.');
    const n = Number(t);
    return Number.isFinite(n) ? n * 1000 : null;
  }
  // Indonesian format: dots group thousands, comma is decimal.
  t = t.replace(/\./g, '').replace(',', '.');
  const n = Number(t);
  return Number.isFinite(n) ? n : null;
}

const clamp01 = (n: number | null, fallback: number) =>
  n === null ? fallback : Math.min(1, Math.max(0, n > 1 ? n / 100 : n));

function isoDate(s: string | null | undefined): string | null {
  if (!s) return null;
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s.trim());
  if (!m) return null;
  const d = new Date(`${m[1]}-${m[2]}-${m[3]}T00:00:00Z`);
  return Number.isNaN(d.getTime()) ? null : `${m[1]}-${m[2]}-${m[3]}`;
}

/**
 * Deterministic post-processing of Gemini output (PRD §13: the backend
 * validates numeric evidence). Never invents values: inconsistencies lower
 * confidence and add a note so the review screen highlights the row.
 */
export function normalize(kind: DocKind, out: ModelOutput): { date: string | null; rows: OutRow[]; expense: OutExpense | null } {
  const date = isoDate(out.date ?? null);

  if (kind === 'expenseReceipt') {
    const e = out.expense;
    if (!e) return { date, rows: [], expense: null };
    const notes: string[] = [];
    let confidence = clamp01(parseAmount(e.confidence), 0.5);
    const amount = parseAmount(e.amount) ?? 0;
    if (amount <= 0) {
      notes.push('Nominal tidak terbaca.');
      confidence = Math.min(confidence, 0.4);
    }
    const category = (EXPENSE_CATEGORIES as readonly string[]).includes(e.category ?? '') ? e.category! : 'Lainnya';
    const typeParsed = ExpenseType.safeParse(e.expense_type);
    return {
      date,
      rows: [],
      expense: {
        description: (e.description ?? '').trim(),
        amount,
        vendor: e.vendor?.trim() || null,
        category,
        type: typeParsed.success ? typeParsed.data : 'businessExpense',
        confidence,
        notes,
      },
    };
  }

  const rows: OutRow[] = [];
  for (const r of out.rows) {
    const name = (r.product_name || r.raw_text || '').trim();
    const qty = parseAmount(r.quantity);
    if (!name || qty === null || qty <= 0) continue; // not a product line
    const notes: string[] = [];
    let confidence = clamp01(parseAmount(r.confidence), 0.5);
    let unitPrice = parseAmount(r.unit_price);
    const unitCost = kind === 'openingStock' || kind === 'serviceIncome' ? parseAmount(r.unit_cost) : null;
    const total = kind === 'dailySales' || kind === 'serviceIncome' ? parseAmount(r.total) : null;

    if (kind === 'dailySales' || kind === 'serviceIncome') {
      if (unitPrice === null && total !== null) {
        unitPrice = Math.round(total / qty);
        notes.push('Harga satuan dihitung dari total ÷ jumlah.');
        confidence = Math.min(confidence, 0.7);
      } else if (unitPrice !== null && total !== null && Math.abs(unitPrice * qty - total) > 1) {
        notes.push(`Jumlah × harga (${unitPrice * qty}) tidak sama dengan total tertulis (${total}).`);
        confidence = Math.min(confidence, 0.6);
      }
      if (unitPrice === null) {
        notes.push('Harga tidak terbaca.');
        confidence = Math.min(confidence, 0.5);
      }
    }
    if (unitPrice !== null && unitPrice < 0) unitPrice = null;

    rows.push({
      ...(r.unit ? { unit: r.unit } : {}),
      rawText: (r.raw_text || name).trim(),
      name,
      qty,
      unitPrice,
      unitCost: unitCost !== null && unitCost >= 0 ? unitCost : null,
      total,
      confidence,
      notes,
    });
  }
  return { date, rows, expense: null };
}
