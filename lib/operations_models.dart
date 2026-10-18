class Offering {
  final String id;
  String name, unit;
  double price;
  double? directCost;
  Offering({
    required this.id,
    required this.name,
    required this.unit,
    required this.price,
    this.directCost,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'unit': unit,
    'price': price,
    'directCost': directCost,
  };
  factory Offering.fromJson(Map<String, dynamic> j) => Offering(
    id: j['id'],
    name: j['name'],
    unit: j['unit'],
    price: (j['price'] as num).toDouble(),
    directCost: (j['directCost'] as num?)?.toDouble(),
  );
}

class MaterialUse {
  final String productId;
  final double qty;
  MaterialUse(this.productId, this.qty);
  Map<String, dynamic> toJson() => {'productId': productId, 'qty': qty};
  factory MaterialUse.fromJson(Map<String, dynamic> j) =>
      MaterialUse(j['productId'], (j['qty'] as num).toDouble());
}

class OrderPayment {
  final String id;
  final double amount;
  final DateTime at;
  final String method;
  OrderPayment(this.id, this.amount, this.at, this.method);
  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
    'at': at.toIso8601String(),
    'method': method,
  };
  factory OrderPayment.fromJson(Map<String, dynamic> j) => OrderPayment(
    j['id'],
    (j['amount'] as num).toDouble(),
    DateTime.parse(j['at']),
    j['method'],
  );
}

class WorkOrder {
  final String id;
  String offeringId, title, customer, asset, condition, treatment, staff, unit;
  double qty, unitPrice;
  double? directCost;
  final DateTime createdAt;
  DateTime dueAt;
  final List<String> stages;
  List<MaterialUse> materials;
  final List<OrderPayment> payments;
  final String? photoDocumentId;
  int stage;
  int durationMinutes;
  bool approved, cancelled;
  String? saleId;
  WorkOrder({
    required this.id,
    required this.offeringId,
    required this.title,
    required this.customer,
    required this.asset,
    required this.condition,
    required this.treatment,
    required this.staff,
    required this.unit,
    required this.qty,
    required this.unitPrice,
    this.directCost,
    required this.createdAt,
    required this.dueAt,
    required this.stages,
    this.stage = 0,
    this.durationMinutes = 60,
    this.approved = false,
    this.cancelled = false,
    this.saleId,
    this.photoDocumentId,
    List<MaterialUse>? materials,
    List<OrderPayment>? payments,
  }) : materials = materials ?? [],
       payments = payments ?? [];
  double get total => qty * unitPrice;
  double get paid => payments.fold(0, (sum, p) => sum + p.amount);
  double get outstanding => (total - paid).clamp(0, double.infinity).toDouble();
  bool get completed => saleId != null;
  String get status =>
      cancelled ? 'Dibatalkan' : stages[stage.clamp(0, stages.length - 1)];
  Map<String, dynamic> toJson() => {
    'id': id,
    'offeringId': offeringId,
    'title': title,
    'customer': customer,
    'asset': asset,
    'condition': condition,
    'treatment': treatment,
    'staff': staff,
    'unit': unit,
    'qty': qty,
    'unitPrice': unitPrice,
    'directCost': directCost,
    'createdAt': createdAt.toIso8601String(),
    'dueAt': dueAt.toIso8601String(),
    'stages': stages,
    'stage': stage,
    'durationMinutes': durationMinutes,
    'approved': approved,
    'cancelled': cancelled,
    'saleId': saleId,
    'photoDocumentId': photoDocumentId,
    'materials': materials.map((m) => m.toJson()).toList(),
    'payments': payments.map((p) => p.toJson()).toList(),
  };
  factory WorkOrder.fromJson(Map<String, dynamic> j) => WorkOrder(
    id: j['id'],
    offeringId: j['offeringId'],
    title: j['title'],
    customer: j['customer'],
    asset: j['asset'] ?? '',
    condition: j['condition'] ?? '',
    treatment: j['treatment'] ?? '',
    staff: j['staff'] ?? '',
    unit: j['unit'],
    qty: (j['qty'] as num).toDouble(),
    unitPrice: (j['unitPrice'] as num).toDouble(),
    directCost: (j['directCost'] as num?)?.toDouble(),
    createdAt: DateTime.parse(j['createdAt']),
    dueAt: DateTime.parse(j['dueAt']),
    stages: List<String>.from(j['stages']),
    stage: j['stage'] ?? 0,
    durationMinutes: j['durationMinutes'] ?? 60,
    approved: j['approved'] == true,
    cancelled: j['cancelled'] == true,
    saleId: j['saleId'],
    photoDocumentId: j['photoDocumentId'],
    materials: (j['materials'] as List? ?? [])
        .map((m) => MaterialUse.fromJson(m))
        .toList(),
    payments: (j['payments'] as List? ?? [])
        .map((p) => OrderPayment.fromJson(p))
        .toList(),
  );
}

class ProductionRecipe {
  final String id, name, outputProductId;
  final double yieldQty;
  final List<MaterialUse> ingredients;
  final double? extraCost;
  ProductionRecipe({
    required this.id,
    required this.name,
    required this.outputProductId,
    required this.yieldQty,
    required this.ingredients,
    this.extraCost,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'outputProductId': outputProductId,
    'yieldQty': yieldQty,
    'ingredients': ingredients.map((m) => m.toJson()).toList(),
    'extraCost': extraCost,
  };
  factory ProductionRecipe.fromJson(Map<String, dynamic> j) => ProductionRecipe(
    id: j['id'],
    name: j['name'],
    outputProductId: j['outputProductId'],
    yieldQty: (j['yieldQty'] as num).toDouble(),
    ingredients: (j['ingredients'] as List)
        .map((m) => MaterialUse.fromJson(m))
        .toList(),
    extraCost: (j['extraCost'] as num?)?.toDouble(),
  );
}

class ProductionRecord {
  final String id, recipeId;
  final double outputQty;
  final double? totalCost;
  final DateTime at;
  ProductionRecord(
    this.id,
    this.recipeId,
    this.outputQty,
    this.totalCost,
    this.at,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'recipeId': recipeId,
    'outputQty': outputQty,
    'totalCost': totalCost,
    'at': at.toIso8601String(),
  };
  factory ProductionRecord.fromJson(Map<String, dynamic> j) => ProductionRecord(
    j['id'],
    j['recipeId'],
    (j['outputQty'] as num).toDouble(),
    (j['totalCost'] as num?)?.toDouble(),
    DateTime.parse(j['at']),
  );
}

class WasteRecord {
  final String id, productId, reason;
  final double qty;
  final double? cost;
  final DateTime at;
  WasteRecord(
    this.id,
    this.productId,
    this.qty,
    this.cost,
    this.reason,
    this.at,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'productId': productId,
    'qty': qty,
    'cost': cost,
    'reason': reason,
    'at': at.toIso8601String(),
  };
  factory WasteRecord.fromJson(Map<String, dynamic> j) => WasteRecord(
    j['id'],
    j['productId'],
    (j['qty'] as num).toDouble(),
    (j['cost'] as num?)?.toDouble(),
    j['reason'],
    DateTime.parse(j['at']),
  );
}
