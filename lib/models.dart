import 'business_types.dart';
import 'operations_models.dart';

// Data models for WarungPilot MVP.
// Unknown costs are always `null`, never 0 (PRD §6, §14).

String newId([String prefix = 'id']) =>
    '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${_seq++}';
int _seq = 0;

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String monthKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

class Business {
  String id;
  String name;
  String ownerName;
  String city;
  BusinessType? type;
  String subtype, purpose, pricingUnit, priority;
  Map<String, dynamic>? understanding;
  DateTime createdAt;
  Business({
    required this.id,
    required this.name,
    required this.ownerName,
    required this.city,
    this.type,
    this.subtype = '',
    this.purpose = '',
    this.pricingUnit = 'unit',
    this.priority = '',
    this.understanding,
    required this.createdAt,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'ownerName': ownerName,
    'city': city,
    'type': type?.name,
    'subtype': subtype,
    'purpose': purpose,
    'pricingUnit': pricingUnit,
    'priority': priority,
    'understanding': understanding,
    'createdAt': createdAt.toIso8601String(),
  };
  factory Business.fromJson(Map<String, dynamic> j) => Business(
    id: j['id'],
    name: j['name'],
    ownerName: j['ownerName'] ?? '',
    city: j['city'] ?? '',
    type: parseBusinessType(j['type']),
    subtype: j['subtype'] ?? '',
    purpose: j['purpose'] ?? '',
    pricingUnit: j['pricingUnit'] ?? 'unit',
    priority: j['priority'] ?? '',
    understanding: j['understanding'] == null
        ? null
        : Map<String, dynamic>.from(j['understanding']),
    createdAt: DateTime.parse(j['createdAt']),
  );
}

enum CostStatus { complete, incomplete }

String normalizedUnit(String value) {
  final unit = value.trim().toLowerCase();
  return switch (unit) {
    'piece' || 'pieces' || 'buah' || 'pc' => 'pcs',
    'packs' => 'pack',
    _ => unit,
  };
}

class Product {
  String id;
  String name;
  List<String> aliases;
  String category;
  String unit;
  double sellPrice;
  double? avgCost; // null = unknown cost basis
  double qty;
  double minQty;
  bool active;
  bool materialOnly;
  Product({
    required this.id,
    required this.name,
    this.aliases = const [],
    this.category = 'Lainnya',
    this.unit = 'pcs',
    required this.sellPrice,
    this.avgCost,
    this.qty = 0,
    this.minQty = 5,
    this.active = true,
    this.materialOnly = false,
  });

  CostStatus get costStatus =>
      avgCost == null ? CostStatus.incomplete : CostStatus.complete;
  bool get isLowStock => qty <= minQty;
  double? get stockValue => avgCost == null ? null : avgCost! * qty;
  double? get marginPct => (avgCost == null || sellPrice <= 0)
      ? null
      : (sellPrice - avgCost!) / sellPrice * 100;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'aliases': aliases,
    'category': category,
    'unit': unit,
    'sellPrice': sellPrice,
    'avgCost': avgCost,
    'qty': qty,
    'minQty': minQty,
    'active': active,
    'materialOnly': materialOnly,
  };
  factory Product.fromJson(Map<String, dynamic> j) => Product(
    id: j['id'],
    name: j['name'],
    aliases: List<String>.from(j['aliases'] ?? const []),
    category: j['category'] ?? 'Lainnya',
    unit: j['unit'] ?? 'pcs',
    sellPrice: (j['sellPrice'] as num).toDouble(),
    avgCost: (j['avgCost'] as num?)?.toDouble(),
    qty: (j['qty'] as num).toDouble(),
    minQty: (j['minQty'] as num).toDouble(),
    active: j['active'] ?? true,
    materialOnly: j['materialOnly'] ?? false,
  );
}

enum MovementType { opening, purchase, sale, returnIn, adjustment }

const movementLabels = {
  MovementType.opening: 'Stok awal',
  MovementType.purchase: 'Pembelian',
  MovementType.sale: 'Penjualan',
  MovementType.returnIn: 'Retur',
  MovementType.adjustment: 'Penyesuaian',
};

class StockMovement {
  String id;
  String productId;
  MovementType type;
  double qtyDelta;
  double? unitCost;
  String sourceId; // sale / purchase / document id
  DateTime date;
  DateTime createdAt;
  StockMovement({
    required this.id,
    required this.productId,
    required this.type,
    required this.qtyDelta,
    this.unitCost,
    required this.sourceId,
    required this.date,
    required this.createdAt,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'productId': productId,
    'type': type.name,
    'qtyDelta': qtyDelta,
    'unitCost': unitCost,
    'sourceId': sourceId,
    'date': date.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };
  factory StockMovement.fromJson(Map<String, dynamic> j) => StockMovement(
    id: j['id'],
    productId: j['productId'],
    type: MovementType.values.byName(j['type']),
    qtyDelta: (j['qtyDelta'] as num).toDouble(),
    unitCost: (j['unitCost'] as num?)?.toDouble(),
    sourceId: j['sourceId'],
    date: DateTime.parse(j['date']),
    createdAt: DateTime.parse(j['createdAt']),
  );
}

enum SaleMode { individual, dailySummary }

class SaleItem {
  final String unit;
  String productId;
  String productName;
  double qty;
  double unitPrice;
  double? cogs; // snapshot at posting; null when cost unknown
  SaleItem({
    this.unit = '',
    required this.productId,
    required this.productName,
    required this.qty,
    required this.unitPrice,
    this.cogs,
  });
  double get total => qty * unitPrice;
  Map<String, dynamic> toJson() => {
    'unit': unit,
    'productId': productId,
    'productName': productName,
    'qty': qty,
    'unitPrice': unitPrice,
    'cogs': cogs,
  };
  factory SaleItem.fromJson(Map<String, dynamic> j) => SaleItem(
    unit: j['unit'] ?? '',
    productId: j['productId'],
    productName: j['productName'],
    qty: (j['qty'] as num).toDouble(),
    unitPrice: (j['unitPrice'] as num).toDouble(),
    cogs: (j['cogs'] as num?)?.toDouble(),
  );
}

class Sale {
  String id;
  DateTime date;
  SaleMode mode;
  List<SaleItem> items;
  String idempotencyKey;
  String? documentId;
  DateTime createdAt;
  Sale({
    required this.id,
    required this.date,
    required this.mode,
    required this.items,
    required this.idempotencyKey,
    this.documentId,
    required this.createdAt,
  });
  double get revenue => items.fold(0, (s, i) => s + i.total);
  bool get cogsComplete => items.every((i) => i.cogs != null);
  double get knownCogs => items.fold(0, (s, i) => s + (i.cogs ?? 0));

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'mode': mode.name,
    'items': items.map((e) => e.toJson()).toList(),
    'idempotencyKey': idempotencyKey,
    'documentId': documentId,
    'createdAt': createdAt.toIso8601String(),
  };
  factory Sale.fromJson(Map<String, dynamic> j) => Sale(
    id: j['id'],
    date: DateTime.parse(j['date']),
    mode: SaleMode.values.byName(j['mode']),
    items: (j['items'] as List).map((e) => SaleItem.fromJson(e)).toList(),
    idempotencyKey: j['idempotencyKey'],
    documentId: j['documentId'],
    createdAt: DateTime.parse(j['createdAt']),
  );
}

enum ExpenseType { businessExpense, personalWithdrawal, inventoryPurchase }

const expenseTypeLabels = {
  ExpenseType.businessExpense: 'Biaya usaha',
  ExpenseType.personalWithdrawal: 'Ambil pribadi',
  ExpenseType.inventoryPurchase: 'Beli stok',
};

const expenseCategories = [
  'Sewa',
  'Listrik & air',
  'Gaji',
  'Transportasi',
  'Pemasaran',
  'Pulsa & internet',
  'Perlengkapan',
  'Perawatan',
  'Lainnya',
];

class Expense {
  String id;
  DateTime date;
  String description;
  String category;
  double amount;
  String? vendor;
  String paymentMethod;
  ExpenseType type;
  String? documentId;
  DateTime createdAt;
  Expense({
    required this.id,
    required this.date,
    required this.description,
    required this.category,
    required this.amount,
    this.vendor,
    this.paymentMethod = 'Tunai',
    required this.type,
    this.documentId,
    required this.createdAt,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'description': description,
    'category': category,
    'amount': amount,
    'vendor': vendor,
    'paymentMethod': paymentMethod,
    'type': type.name,
    'documentId': documentId,
    'createdAt': createdAt.toIso8601String(),
  };
  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
    id: j['id'],
    date: DateTime.parse(j['date']),
    description: j['description'],
    category: j['category'],
    amount: (j['amount'] as num).toDouble(),
    vendor: j['vendor'],
    paymentMethod: j['paymentMethod'] ?? 'Tunai',
    type: ExpenseType.values.byName(j['type']),
    documentId: j['documentId'],
    createdAt: DateTime.parse(j['createdAt']),
  );
}

/// Kind of document captured in the Scan flow.
enum DocKind { openingStock, dailySales, expenseReceipt, serviceIncome }

const docKindLabels = {
  DocKind.serviceIncome: 'Layanan selesai',
  DocKind.openingStock: 'Stok awal',
  DocKind.dailySales: 'Penjualan harian',
  DocKind.expenseReceipt: 'Struk / nota biaya',
};

enum DocStatus { processing, draft, failed, posted, cancelled }

/// One extracted row. All fields editable in review; `confidence` < 0.75 is
/// highlighted as unclear.
class DraftRow {
  String unit;
  List<MaterialUse> materials;
  String rawText;
  String name;
  String? productId; // matched product (sales) or null = new product
  double qty;
  double? unitPrice; // selling price (sales/opening)
  double? unitCost; // purchase cost (opening)
  double confidence;
  List<String> candidates; // product ids suggested by matcher
  bool include;
  bool learned; // matched via an alias the owner confirmed earlier
  DraftRow({
    this.unit = 'unit',
    this.materials = const [],
    required this.rawText,
    required this.name,
    this.productId,
    required this.qty,
    this.unitPrice,
    this.unitCost,
    this.confidence = 1,
    this.candidates = const [],
    this.include = true,
    this.learned = false,
  });
  bool get unclear => confidence < 0.75;
  DraftRow copy() => DraftRow(
    unit: unit,
    materials: materials.map((m) => MaterialUse.fromJson(m.toJson())).toList(),
    rawText: rawText,
    name: name,
    productId: productId,
    qty: qty,
    unitPrice: unitPrice,
    unitCost: unitCost,
    confidence: confidence,
    candidates: List.of(candidates),
    include: include,
    learned: learned,
  );
  Map<String, dynamic> toJson() => {
    'materials': materials.map((m) => m.toJson()).toList(),
    'rawText': rawText,
    'unit': unit,
    'name': name,
    'productId': productId,
    'qty': qty,
    'unitPrice': unitPrice,
    'unitCost': unitCost,
    'confidence': confidence,
    'candidates': candidates,
    'include': include,
    'learned': learned,
  };
  factory DraftRow.fromJson(Map<String, dynamic> j) => DraftRow(
    unit: j['unit'] ?? 'unit',
    materials: ((j['materials'] ?? []) as List)
        .map((m) => MaterialUse.fromJson(m))
        .toList(),
    rawText: j['rawText'] ?? '',
    name: j['name'],
    productId: j['productId'],
    qty: (j['qty'] as num).toDouble(),
    unitPrice: (j['unitPrice'] as num?)?.toDouble(),
    unitCost: (j['unitCost'] as num?)?.toDouble(),
    confidence: (j['confidence'] as num?)?.toDouble() ?? 1,
    candidates: List<String>.from(j['candidates'] ?? const []),
    include: j['include'] ?? true,
    learned: j['learned'] ?? false,
  );
}

/// Expense extracted from a receipt.
class DraftExpense {
  String description;
  String category;
  double amount;
  String? vendor;
  ExpenseType type;
  double confidence;
  List<String> flags;
  DraftExpense({
    required this.description,
    required this.category,
    required this.amount,
    this.vendor,
    required this.type,
    this.confidence = 1,
    this.flags = const [],
  });
  Map<String, dynamic> toJson() => {
    'description': description,
    'category': category,
    'amount': amount,
    'vendor': vendor,
    'type': type.name,
    'confidence': confidence,
    'flags': flags,
  };
  factory DraftExpense.fromJson(Map<String, dynamic> j) => DraftExpense(
    description: j['description'],
    category: j['category'],
    amount: (j['amount'] as num).toDouble(),
    vendor: j['vendor'],
    type: ExpenseType.values.byName(j['type']),
    confidence: (j['confidence'] as num?)?.toDouble() ?? 1,
    flags: List<String>.from(j['flags'] ?? const []),
  );
}

/// Source document: preserves raw AI output and corrected draft (PRD §14).
class SourceDocument {
  bool servicesCompleted;
  String id;
  DocKind kind;
  DocStatus status;
  DateTime date;
  SaleMode saleMode;
  String? imagePath;
  bool photoStored;
  bool manualEntry;
  List<DraftRow> rawRows; // as returned by AI
  List<DraftRow> rows; // user-corrected draft
  DraftExpense? expense;
  List<String> postedRefs;
  String? error;
  DateTime createdAt;
  SourceDocument({
    this.servicesCompleted = false,
    required this.id,
    required this.kind,
    required this.status,
    required this.date,
    this.saleMode = SaleMode.dailySummary,
    this.imagePath,
    this.photoStored = false,
    this.manualEntry = false,
    this.rawRows = const [],
    this.rows = const [],
    this.expense,
    this.postedRefs = const [],
    this.error,
    required this.createdAt,
  });
  Map<String, dynamic> toJson() => {
    'servicesCompleted': servicesCompleted,
    'id': id,
    'kind': kind.name,
    'status': status.name,
    'date': date.toIso8601String(),
    'saleMode': saleMode.name,
    'imagePath': imagePath,
    'photoStored': photoStored,
    'manualEntry': manualEntry,
    'rawRows': rawRows.map((e) => e.toJson()).toList(),
    'rows': rows.map((e) => e.toJson()).toList(),
    'expense': expense?.toJson(),
    'postedRefs': postedRefs,
    'error': error,
    'createdAt': createdAt.toIso8601String(),
  };
  factory SourceDocument.fromJson(Map<String, dynamic> j) => SourceDocument(
    servicesCompleted: j['servicesCompleted'] == true,
    id: j['id'],
    kind: DocKind.values.byName(j['kind']),
    status: DocStatus.values.byName(j['status']),
    date: DateTime.parse(j['date']),
    saleMode: SaleMode.values.byName(j['saleMode'] ?? 'dailySummary'),
    imagePath: j['imagePath'],
    photoStored: j['photoStored'] == true,
    manualEntry:
        j['manualEntry'] == true ||
        ((j['rows'] ?? []) as List).any(
          (r) => r['rawText'] == '(input manual)',
        ),
    rawRows: ((j['rawRows'] ?? []) as List)
        .map((e) => DraftRow.fromJson(e))
        .toList(),
    rows: ((j['rows'] ?? []) as List).map((e) => DraftRow.fromJson(e)).toList(),
    expense: j['expense'] == null ? null : DraftExpense.fromJson(j['expense']),
    postedRefs: List<String>.from(j['postedRefs'] ?? const []),
    error: j['error'],
    createdAt: DateTime.parse(j['createdAt']),
  );
}

enum InsightPriority { high, medium, low }

class Insight {
  final String id; // stable per subject (e.g. low_<productId>) — feedback key
  final InsightKind kind;
  final String category;
  final String title;
  final InsightPriority priority;
  final List<String> evidence;
  final String action;
  final String? caveat;
  final String? missionId;
  final String? whyForYou; // personalization explanation, set by ranking
  const Insight({
    required this.id,
    required this.kind,
    required this.category,
    required this.title,
    required this.priority,
    required this.evidence,
    required this.action,
    this.caveat,
    this.missionId,
    this.whyForYou,
  });

  Insight withWhy(String? why) => Insight(
    id: id,
    kind: kind,
    category: category,
    title: title,
    priority: priority,
    evidence: evidence,
    action: action,
    caveat: caveat,
    missionId: missionId,
    whyForYou: why,
  );
}

class Mission {
  final String id;
  final String title;
  final String description;
  final int xp;
  final bool fromAi;
  final double progress; // 0..1, computed from confirmed data
  final bool claimed;
  const Mission({
    required this.id,
    required this.title,
    required this.description,
    required this.xp,
    this.fromAi = false,
    required this.progress,
    required this.claimed,
  });
  bool get verified => progress >= 1;
}

class XpEvent {
  String key; // unique award key — guarantees award-once
  String label;
  int xp;
  DateTime at;
  XpEvent({
    required this.key,
    required this.label,
    required this.xp,
    required this.at,
  });
  Map<String, dynamic> toJson() => {
    'key': key,
    'label': label,
    'xp': xp,
    'at': at.toIso8601String(),
  };
  factory XpEvent.fromJson(Map<String, dynamic> j) => XpEvent(
    key: j['key'],
    label: j['label'],
    xp: j['xp'],
    at: DateTime.parse(j['at']),
  );
}

// ------------------------------------------------- owner intelligence (§10.1)

enum InsightKind {
  onboarding,
  lowStock,
  missingCost,
  marginRisk,
  salesChange,
  topProduct,
  expense,
  recordHabit,
}

/// The one business goal the owner picks at onboarding.
enum OwnerGoal { stockAvailability, profitability, recordCompleteness }

const ownerGoalLabels = {
  OwnerGoal.stockAvailability: 'Stok selalu tersedia',
  OwnerGoal.profitability: 'Untung lebih besar',
  OwnerGoal.recordCompleteness: 'Catatan rapi & lengkap',
};

const ownerGoalDescriptions = {
  OwnerGoal.stockAvailability: 'Jangan sampai barang laku kehabisan.',
  OwnerGoal.profitability: 'Tahu laba sebenarnya & jaga margin.',
  OwnerGoal.recordCompleteness: 'Rutin mencatat supaya angka bisa dipercaya.',
};

/// Insight kinds that matter most for each goal (rules-based relevance).
const goalKinds = {
  OwnerGoal.stockAvailability: {
    InsightKind.lowStock,
    InsightKind.topProduct,
    InsightKind.salesChange,
  },
  OwnerGoal.profitability: {
    InsightKind.marginRisk,
    InsightKind.missingCost,
    InsightKind.expense,
  },
  OwnerGoal.recordCompleteness: {
    InsightKind.recordHabit,
    InsightKind.missingCost,
    InsightKind.onboarding,
  },
};

enum ExplainStyle { concise, detailed }

/// owner_ai_profile: explicit preferences + confirmed aliases. Never holds
/// sensitive personal traits; scoped to one business; owner can reset it.
class OwnerAiProfile {
  OwnerGoal goal;
  ExplainStyle style;
  Map<String, String> aliases; // normalized handwritten text → productId
  Set<String> skippedMissions; // "<missionId>_<day>"
  DateTime updatedAt;
  OwnerAiProfile({
    this.goal = OwnerGoal.stockAvailability,
    this.style = ExplainStyle.concise,
    Map<String, String>? aliases,
    Set<String>? skippedMissions,
    required this.updatedAt,
  }) : aliases = aliases ?? {},
       skippedMissions = skippedMissions ?? {};

  Map<String, dynamic> toJson() => {
    'goal': goal.name,
    'style': style.name,
    'aliases': aliases,
    'skippedMissions': skippedMissions.toList(),
    'updatedAt': updatedAt.toIso8601String(),
  };
  factory OwnerAiProfile.fromJson(Map<String, dynamic> j) => OwnerAiProfile(
    goal: OwnerGoal.values.byName(j['goal'] ?? 'stockAvailability'),
    style: ExplainStyle.values.byName(j['style'] ?? 'concise'),
    aliases: Map<String, String>.from(j['aliases'] ?? const {}),
    skippedMissions: Set<String>.from(j['skippedMissions'] ?? const []),
    updatedAt: DateTime.parse(j['updatedAt']),
  );
}

/// insight_feedback: one row per insight the owner rated.
class InsightFeedback {
  final String insightId;
  final InsightKind kind;
  final bool useful;
  final DateTime at;
  InsightFeedback({
    required this.insightId,
    required this.kind,
    required this.useful,
    required this.at,
  });
  Map<String, dynamic> toJson() => {
    'insightId': insightId,
    'kind': kind.name,
    'useful': useful,
    'at': at.toIso8601String(),
  };
  factory InsightFeedback.fromJson(Map<String, dynamic> j) => InsightFeedback(
    insightId: j['insightId'],
    kind: InsightKind.values.byName(j['kind']),
    useful: j['useful'],
    at: DateTime.parse(j['at']),
  );
}
