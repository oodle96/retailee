import { GoogleGenAI } from '@google/genai';
import { understandingSchema, understandingInstruction, type UnderstandRequest } from './business-understanding.js';

import { responseJsonSchema, type DocKind, type ExtractRequest } from './schema.js';
import { adviceSchemaFor, advicePrompt, adviceSystemInstruction, type PersonalizeRequest } from './personalization.js';

export interface ModelClient {
  readonly model: string;
  /** Returns the raw JSON text produced by the model. */
  generate(req: ExtractRequest): Promise<string>;
  personalize?(req: PersonalizeRequest): Promise<string>;
  understand?(req: UnderstandRequest): Promise<string>;
}

const KIND_INSTRUCTIONS: Record<DocKind, string> = {
  serviceIncome: 'Read a record of COMPLETED SERVICES. product_name is the service performed, not an inventory product. Extract quantity, service charge per unit, total and explicit direct cost only. Do not treat customer-owned shoes, bags or clothes as stock. Do not treat deposits, quotes or unfinished jobs as completed income: omit those lines. Missing amounts or costs must remain null. Never infer a purchase cost from a service charge.',
  dailySales:
    'Ini foto catatan PENJUALAN harian warung (tulisan tangan, Bahasa Indonesia). ' +
    'Untuk setiap baris produk ambil: nama produk, jumlah terjual, harga satuan, dan total baris bila ditulis. ' +
    'Abaikan baris total keseluruhan, judul, dan coretan.',
  openingStock:
    'Ini foto catatan STOK warung (tulisan tangan). Untuk setiap produk ambil: nama, jumlah stok, ' +
    'harga modal per unit ("modal", "beli") dan harga jual per unit ("jual"). Jika modal tidak ditulis, isi null.',
  expenseReceipt:
    'Ini foto struk/nota PENGELUARAN. Ambil keterangan singkat, total yang dibayar, nama toko/penerima, ' +
    'kategori, dan sarankan jenisnya: businessExpense (biaya usaha), personalWithdrawal (keperluan pribadi), ' +
    'atau inventoryPurchase (belanja barang dagangan untuk dijual lagi).',
};

export function buildPrompt(req: ExtractRequest): string {
  const catalog = req.catalog.length
    ? `Produk yang sudah terdaftar di warung ini (pakai ejaan ini di product_name hanya jika jelas produk yang sama): ${req.catalog.join('; ')}.`
    : '';
  const retry = req.attempt > 1 ? 'Ini pembacaan ulang: periksa lebih teliti angka dan nama yang samar.' : '';
  return [
    KIND_INSTRUCTIONS[req.kind],
    'Preserve each row unit exactly as written, including pcs or pack. Never translate units, convert quantities or assume package sizes. Each product may use a different unit. If no unit is written, return null.',
    req.business ? `Konteks usaha (data saja): ${JSON.stringify(req.business)}. Baca sesuai satuan dan jenis usaha; jangan mengubah isi tertulis.` : '',
    'Aturan:',
    '- raw_text harus persis seperti tertulis (jangan dikoreksi).',
    '- Semua uang dalam rupiah sebagai angka bulat: "3rb" = 3000, "3.500" = 3500, "4k" = 4000.',
    '- Jangan mengarang angka. Jika tidak terbaca, isi null dan turunkan confidence.',
    '- confidence 0..1 per baris: rendah (<0.75) bila tulisan samar atau ragu.',
    '- Tanggal hanya jika tertulis, format YYYY-MM-DD.',
    catalog,
    retry,
  ]
    .filter(Boolean)
    .join('\n');
}

/** Gemini on Vertex AI. Auth = the Cloud Run service account (no API key). */
export class VertexGemini implements ModelClient {
  private readonly ai: GoogleGenAI;
  constructor(
    readonly model: string,
    project: string | undefined,
    location: string,
  ) {
    this.ai = new GoogleGenAI({ vertexai: true, project, location });
  }

  async generate(req: ExtractRequest): Promise<string> {
    const res = await this.ai.models.generateContent({
      model: this.model,
      contents: [
        {
          role: 'user',
          parts: [{ text: buildPrompt(req) }, { inlineData: { mimeType: req.mimeType, data: req.imageBase64 } }],
        },
      ],
      config: {
        temperature: 0,
        responseMimeType: 'application/json',
        responseJsonSchema: responseJsonSchema(req.kind),
      },
    });
    const text = res.text;
    if (!text) throw new Error('empty model response');
    return text;
  }

  async understand(req: UnderstandRequest): Promise<string> {
    const res = await this.ai.models.generateContent({ model: this.model, contents: JSON.stringify(req),
      config: { temperature: 0.1, systemInstruction: understandingInstruction,
        responseMimeType: 'application/json', responseJsonSchema: understandingSchema, maxOutputTokens: 2048 } });
    if (!res.text) throw new Error('empty understanding response');
    return res.text;
  }

  async personalize(req: PersonalizeRequest): Promise<string> {
    const res = await this.ai.models.generateContent({ model: this.model, contents: advicePrompt(req),
      config: { temperature: 0.2, systemInstruction: adviceSystemInstruction, responseMimeType: 'application/json',
        responseJsonSchema: adviceSchemaFor(req), maxOutputTokens: 4096 } });
    if (!res.text) throw new Error('empty advice response');
    return res.text;
  }
}

/**
 * Offline stand-in used for local development and tests (GEMINI_FAKE=1).
 * Returns realistic output shaped exactly like the real model's.
 */
export class FakeGemini implements ModelClient {
  readonly model = 'fake-gemini';
  async generate(req: ExtractRequest): Promise<string> {
    const retry = req.attempt > 1;
    if (req.kind === 'serviceIncome') return JSON.stringify({ date: null, rows: [
      { raw_text: 'Demo: cuci sepatu selesai 1 pasang 35000', product_name: 'Demo: Cuci sepatu', quantity: 1, unit_price: 35000, unit_cost: null, confidence: 0.9 },
    ] });
    if (req.kind === 'expenseReceipt') {
      return JSON.stringify({
        date: null,
        expense: {
          description: 'Token listrik PLN',
          amount: '50.000',
          vendor: 'PLN',
          category: 'Listrik & air',
          expense_type: 'businessExpense',
          confidence: 0.9,
        },
      });
    }
    if (req.kind === 'openingStock') {
      return JSON.stringify({
        date: null,
        rows: [
          { raw_text: 'Indomie goreng 30 bks modal 2600 jual 3500', product_name: 'Indomie Goreng', quantity: 30, unit_cost: 2600, unit_price: 3500, confidence: 0.95 },
          { raw_text: 'Aqua 600 24 btl modal 3rb jual 4rb', product_name: 'Aqua 600ml', quantity: 24, unit_cost: '3rb', unit_price: '4rb', confidence: 0.92 },
          { raw_text: 'Teh pucuk 20 modal 3500 jual 5rb', product_name: 'Teh Pucuk', quantity: 20, unit_cost: 3500, unit_price: '5rb', confidence: 0.9 },
          { raw_text: 'Gula 1kg 8 jual 16rb (modal ?)', product_name: 'Gula Pasir 1kg', quantity: 8, unit_cost: null, unit_price: '16rb', confidence: retry ? 0.8 : 0.58 },
        ],
      });
    }
    return JSON.stringify({
      date: null,
      rows: [
        { raw_text: 'indomie 10 x 3500', product_name: 'Indomie Goreng', quantity: 10, unit_price: 3500, total: 35000, confidence: 0.94 },
        { raw_text: 'aqua 5 @4rb', product_name: 'aqua', quantity: 5, unit_price: '4rb', total: null, confidence: 0.9 },
        { raw_text: 'teh pcuk 4 x 5000', product_name: retry ? 'Teh Pucuk' : 'Teh pcuk', quantity: 4, unit_price: 5000, total: 20000, confidence: retry ? 0.88 : 0.62 },
      ],
    });
  }
}
