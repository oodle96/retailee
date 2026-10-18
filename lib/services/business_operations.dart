part of 'store.dart';

extension BusinessOperations on AppStore {
  BusinessType get businessType => business?.type ?? BusinessType.retail;
  BusinessTemplate get template => businessTemplates[businessType]!;
  Set<String> get businessActivities {
    final saved = business?.understanding?['activities'];
    if (saved is List) {
      final valid = saved
          .whereType<String>()
          .map((a) => a == 'production' ? 'resale' : a)
          .where(businessActivityLabels.containsKey)
          .toSet();
      if (valid.isNotEmpty) return valid;
    }
    final mode = business?.understanding?['mode'];
    if (mode == 'mixed') {
      return {'services', 'resale'};
    }
    if (mode == 'services') return {'services'};
    return {
      template.producesGoods
          ? 'resale'
          : template.stockFirst || mode == 'goods'
          ? 'resale'
          : 'services',
    };
  }

  bool get hasServices => businessActivities.contains('services');
  bool get hasGoods => businessActivities.contains('resale') || producesGoods;
  // Kept for older saved recipes; production is outside the current app scope.
  bool get producesGoods => false;
  bool get serviceFirst => hasServices && (!hasGoods || !template.stockFirst);
  bool get mixedBusiness => hasServices && hasGoods;
  Future<void> saveUnderstanding(Map<String, dynamic> value) async {
    business!.understanding = Map.of(value);
    advice = null;
    adviceContextSaved = null;
    await _save();
  }

  List<Mission> get operationalMissions {
    Mission mission(String id, String title, String description, bool done) =>
        Mission(
          id: id,
          title: title,
          description: description,
          xp: XpRules.dailyMission,
          progress: done ? 1 : 0,
          claimed: hasAward(
            id.startsWith('daily_') ? 'mission_${id}_$today' : 'mission_$id',
          ),
        );
    return [
      mission(
        'starter_services',
        'Tambahkan layanan dan harga',
        'Gunakan satuan harga yang biasa dipakai pelanggan.',
        offerings.isNotEmpty,
      ),
      mission(
        'starter_order',
        'Catat pesanan pertama',
        'Isi pelanggan, pekerjaan dan tenggat.',
        orders.any((o) => !o.cancelled),
      ),
      mission(
        'daily_orders',
        businessType == BusinessType.beauty
            ? 'Catat janji layanan hari ini'
            : 'Catat pesanan hari ini',
        'Catat pekerjaan yang benar-benar diterima.',
        orders.any((o) => !o.cancelled && dayKey(o.createdAt) == today),
      ),
      mission(
        'daily_completion',
        'Selesaikan pekerjaan yang sudah beres',
        'Perbarui status setelah pekerjaan benar-benar selesai.',
        orders.any(
          (o) =>
              o.saleId != null &&
              sales.any((s) => s.id == o.saleId && dayKey(s.date) == today),
        ),
      ),
      mission(
        'daily_payment',
        'Catat pembayaran pelanggan',
        'Catat hanya pembayaran yang sudah diterima.',
        orders.any(
          (o) => o.payments.any((p) => p.amount > 0 && dayKey(p.at) == today),
        ),
      ),
      mission(
        'daily_expense',
        'Catat biaya usaha hari ini',
        'Biaya umum di luar biaya pesanan.',
        expenses.any(
          (e) =>
              dayKey(e.date) == today && e.type == ExpenseType.businessExpense,
        ),
      ),
    ];
  }

  List<Mission> get productionMissions => [
    Mission(
      id: 'starter_recipe',
      title: 'Buat resep / komposisi produk',
      description: 'Hubungkan bahan baku dengan hasil produksi.',
      xp: XpRules.dailyMission,
      progress: recipes.isNotEmpty ? 1 : 0,
      claimed: hasAward('mission_starter_recipe'),
    ),
    Mission(
      id: 'daily_production',
      title: 'Catat hasil produksi hari ini',
      description: 'Catat batch yang benar-benar dibuat.',
      xp: XpRules.dailyMission,
      progress: productionRecords.any((r) => dayKey(r.at) == today) ? 1 : 0,
      claimed: hasAward('mission_daily_production_$today'),
    ),
  ];
  List<WorkOrder> get activeOrders =>
      orders.where((o) => !o.cancelled && !o.completed).toList();
  double get orderReceivables => orders
      .where((o) => !o.cancelled)
      .fold(0, (sum, o) => sum + o.outstanding);
  Map<String, dynamic> get businessContext => {
    'activities': businessActivities.toList(),
    'understanding': business?.understanding?['summary'] ?? '',
    if (business?.understanding?['mode'] != null)
      'mode': business!.understanding!['mode'],
    'language': languageCode,
    'type': businessType.name,
    'subtype': business?.subtype ?? '',
    'purpose': business?.purpose ?? '',
    'pricingUnit': business?.pricingUnit ?? template.unit,
    'goal': business?.priority.isNotEmpty == true
        ? business!.priority
        : ownerGoalLabels[profile?.goal ?? OwnerGoal.recordCompleteness]!,
    'style': (profile?.style ?? ExplainStyle.concise).name,
  };

  Future<void> configureBusiness({
    required BusinessType type,
    required String subtype,
    required String purpose,
    required String pricingUnit,
    String priority = '',
  }) async {
    if (business == null) throw StateError('Profil usaha belum ada.');
    if (subtype.length > 160 ||
        purpose.length > 600 ||
        pricingUnit.trim().isEmpty ||
        pricingUnit.length > 32 ||
        priority.length > 100) {
      throw StateError('Profil usaha tidak valid.');
    }
    business!
      ..understanding = null
      ..type = type
      ..subtype = subtype.trim()
      ..purpose = purpose.trim()
      ..pricingUnit = pricingUnit.trim()
      ..priority = priority;
    advice = null;
    adviceContextSaved = null;
    await _save();
  }

  void _amount(double value, String label, {bool positive = false}) {
    if (!value.isFinite || value < 0 || (positive && value == 0)) {
      throw StateError('$label tidak valid.');
    }
  }

  Future<void> addOffering(
    String name,
    String unit,
    double price,
    double? cost,
  ) async {
    if (name.trim().isEmpty || unit.trim().isEmpty) {
      throw StateError('Isi nama layanan dan satuannya.');
    }
    _amount(price, 'Harga', positive: true);
    if (cost != null) _amount(cost, 'Biaya');
    offerings.add(
      Offering(
        id: newId('svc'),
        name: name.trim(),
        unit: unit.trim(),
        price: price,
        directCost: cost,
      ),
    );
    await _save();
  }

  Future<void> editOffering(
    Offering offering,
    String name,
    String unit,
    double price,
    double? cost,
  ) async {
    if (name.trim().isEmpty || unit.trim().isEmpty) {
      throw StateError('Nama dan satuan wajib diisi.');
    }
    _amount(price, 'Harga', positive: true);
    if (cost != null) _amount(cost, 'Biaya');
    offering
      ..name = name.trim()
      ..unit = unit.trim()
      ..price = price
      ..directCost = cost;
    await _save();
  }

  Map<String, double> _materialNeeds(
    List<MaterialUse> lines, [
    double multiplier = 1,
  ]) {
    final needed = <String, double>{};
    for (final line in lines) {
      _amount(line.qty, 'Jumlah bahan', positive: true);
      needed[line.productId] =
          (needed[line.productId] ?? 0) + line.qty * multiplier;
    }
    for (final e in needed.entries) {
      _amount(e.value, 'Jumlah bahan', positive: true);
      final p = productById(e.key);
      if (p == null || !p.active) throw StateError('Bahan tidak ditemukan.');
      if (p.qty + 0.000001 < e.value) {
        throw StateError(
          'Stok ${p.name} tidak cukup. Tersedia ${fmtQty(p.qty)} ${p.unit}.',
        );
      }
    }
    return needed;
  }

  double? _consume(
    Map<String, double> needed,
    String sourceId, [
    DateTime? date,
  ]) {
    double? total = 0;
    for (final e in needed.entries) {
      final p = productById(e.key)!;
      total = total == null || p.avgCost == null
          ? null
          : total + e.value * p.avgCost!;
      p.qty -= e.value;
      movements.add(
        StockMovement(
          id: newId('mv'),
          productId: p.id,
          type: MovementType.adjustment,
          qtyDelta: -e.value,
          unitCost: p.avgCost,
          sourceId: sourceId,
          date: date ?? now,
          createdAt: now,
        ),
      );
    }
    return total;
  }

  Future<WorkOrder> createOrder({
    required Offering offering,
    required double qty,
    required double unitPrice,
    required String customer,
    required DateTime dueAt,
    String asset = '',
    String condition = '',
    String treatment = '',
    String staff = '',
    int durationMinutes = 60,
    double? directCost,
    List<MaterialUse> materials = const [],
    Uint8List? photo,
  }) async {
    _amount(qty, 'Jumlah', positive: true);
    _amount(unitPrice, 'Harga', positive: true);
    if (customer.trim().isEmpty) {
      throw StateError('Isi nama atau kode pelanggan.');
    }
    if (directCost != null) _amount(directCost, 'Biaya langsung');
    if (durationMinutes < 5 || durationMinutes > 1440) {
      throw StateError('Durasi harus antara 5 dan 1440 menit.');
    }
    if (businessType == BusinessType.beauty && staff.trim().isEmpty) {
      throw StateError('Isi nama staf untuk memeriksa benturan jadwal.');
    }
    if (businessType == BusinessType.beauty &&
        activeOrders.any(
          (o) =>
              o.staff.toLowerCase() == staff.trim().toLowerCase() &&
              dueAt.isBefore(
                o.dueAt.add(Duration(minutes: o.durationMinutes)),
              ) &&
              o.dueAt.isBefore(dueAt.add(Duration(minutes: durationMinutes))),
        )) {
      throw StateError('Jadwal staf bertabrakan dengan layanan lain.');
    }
    _materialNeeds(materials);
    final id = newId('order');
    String? photoId;
    if (photo != null) {
      if (google == null || _uid == null) {
        throw StateError('Foto barang memerlukan akun Google.');
      }
      photoId = '${id}_condition';
      await google!.uploadPhoto(_uid!, photoId, photo);
    }
    final order = WorkOrder(
      id: id,
      offeringId: offering.id,
      title: offering.name,
      customer: customer.trim(),
      asset: asset.trim(),
      condition: condition.trim(),
      treatment: treatment.trim(),
      staff: staff.trim(),
      unit: offering.unit,
      qty: qty,
      unitPrice: unitPrice,
      directCost: directCost,
      createdAt: now,
      dueAt: dueAt,
      stages: List.of(template.stages),
      durationMinutes: durationMinutes,
      materials: List.of(materials),
      photoDocumentId: photoId,
    );
    orders.add(order);
    _award('first_order', 'Pesanan pertama tercatat', 30);
    await _save();
    return order;
  }

  Future<void> approveOrder(WorkOrder order) async {
    if (order.cancelled || order.completed) {
      throw StateError('Pesanan sudah ditutup.');
    }
    order.approved = true;
    await _save();
  }

  Future<void> updateOrder(
    WorkOrder order, {
    required Offering offering,
    required double qty,
    required double unitPrice,
    required String customer,
    required DateTime dueAt,
    required String asset,
    required String condition,
    required String treatment,
    required String staff,
    required int durationMinutes,
    double? directCost,
    required List<MaterialUse> materials,
  }) async {
    if (order.completed || order.cancelled) {
      throw StateError('Pesanan sudah ditutup.');
    }
    _amount(qty, 'Jumlah', positive: true);
    _amount(unitPrice, 'Harga', positive: true);
    if (directCost != null) _amount(directCost, 'Biaya langsung');
    if (customer.trim().isEmpty ||
        durationMinutes < 5 ||
        durationMinutes > 1440) {
      throw StateError('Periksa pelanggan dan durasi.');
    }
    if (qty * unitPrice + 0.001 < order.paid) {
      throw StateError(
        'Tagihan baru lebih kecil dari pembayaran. Catat pengembalian terlebih dahulu.',
      );
    }
    if (order.stages.first == 'Dijadwalkan') {
      if (staff.trim().isEmpty) throw StateError('Isi staf yang melayani.');
      if (activeOrders.any(
        (o) =>
            o.id != order.id &&
            o.staff.toLowerCase() == staff.trim().toLowerCase() &&
            dueAt.isBefore(o.dueAt.add(Duration(minutes: o.durationMinutes))) &&
            o.dueAt.isBefore(dueAt.add(Duration(minutes: durationMinutes))),
      )) {
        throw StateError('Jadwal staf bertabrakan.');
      }
    }
    _materialNeeds(materials);
    order
      ..offeringId = offering.id
      ..title = offering.name
      ..unit = offering.unit
      ..qty = qty
      ..unitPrice = unitPrice
      ..directCost = directCost
      ..customer = customer.trim()
      ..dueAt = dueAt
      ..asset = asset.trim()
      ..condition = condition.trim()
      ..treatment = treatment.trim()
      ..staff = staff.trim()
      ..durationMinutes = durationMinutes
      ..materials = List.of(materials);
    if (order.stages.contains('Menunggu persetujuan')) order.approved = false;
    await _save();
  }

  Future<void> advanceOrder(WorkOrder order) async {
    if (order.cancelled || order.completed) return;
    final next = order.stage + 1;
    if (next >= order.stages.length) return;
    if (order.stages.contains('Menunggu persetujuan') &&
        next > order.stages.indexOf('Menunggu persetujuan') &&
        !order.approved) {
      throw StateError(
        'Catat persetujuan pelanggan sebelum pekerjaan dilanjutkan.',
      );
    }
    if (next == order.stages.length - 1) {
      final key = 'work_${order.id}';
      if (sales.any((s) => s.idempotencyKey == key)) return;
      final needed = _materialNeeds(order.materials);
      final materialCost = _consume(needed, order.id);
      final cost = materialCost == null || order.directCost == null
          ? null
          : materialCost + order.directCost! * order.qty;
      final sale = Sale(
        id: newId('sale'),
        date: now,
        mode: SaleMode.individual,
        items: [
          SaleItem(
            productId: order.offeringId,
            productName: order.title,
            qty: order.qty,
            unitPrice: order.unitPrice,
            cogs: cost,
          ),
        ],
        idempotencyKey: key,
        createdAt: now,
      );
      sales.add(sale);
      order.saleId = sale.id;
      _award('order_done_${order.id}', 'Pesanan selesai', 20);
    }
    order.stage = next;
    await _save();
  }

  Future<void> recordPayment(
    WorkOrder order,
    double amount,
    String method, {
    bool refund = false,
  }) async {
    _amount(amount, 'Pembayaran', positive: true);
    if (order.cancelled) throw StateError('Pesanan dibatalkan.');
    if (refund && order.completed) {
      throw StateError('Pengembalian pesanan selesai perlu koreksi penjualan.');
    }
    if (refund
        ? amount > order.paid + 0.001
        : amount > order.outstanding + 0.001) {
      throw StateError('Nominal melebihi saldo pesanan.');
    }
    order.payments.add(
      OrderPayment(newId('pay'), refund ? -amount : amount, now, method),
    );
    await _save();
  }

  Future<void> cancelOrder(WorkOrder order) async {
    if (order.completed) {
      throw StateError('Pesanan selesai tidak dapat dibatalkan.');
    }
    if (order.paid > 0.001) {
      throw StateError('Catat pengembalian uang muka terlebih dahulu.');
    }
    order.cancelled = true;
    await _save();
  }

  Future<void> addRecipe(
    String name,
    Product output,
    double yieldQty,
    List<MaterialUse> ingredients,
    double? extraCost,
  ) async {
    if (name.trim().isEmpty || ingredients.isEmpty) {
      throw StateError('Isi nama dan minimal satu bahan.');
    }
    _amount(yieldQty, 'Hasil produksi', positive: true);
    if (extraCost != null) _amount(extraCost, 'Biaya tambahan');
    for (final m in ingredients) {
      _amount(m.qty, 'Jumlah bahan', positive: true);
      if (m.productId == output.id || productById(m.productId) == null) {
        throw StateError('Pilih bahan yang berbeda dari produk hasil.');
      }
    }
    recipes.add(
      ProductionRecipe(
        id: newId('recipe'),
        name: name.trim(),
        outputProductId: output.id,
        yieldQty: yieldQty,
        ingredients: ingredients,
        extraCost: extraCost,
      ),
    );
    await _save();
  }

  Future<void> produce(
    ProductionRecipe recipe,
    double multiplier,
    String operationId,
  ) async {
    _amount(multiplier, 'Jumlah batch', positive: true);
    if (productionRecords.any((r) => r.id == operationId)) return;
    final output = productById(recipe.outputProductId);
    if (output == null || !output.active) {
      throw StateError('Produk hasil tidak tersedia.');
    }
    final needed = _materialNeeds(recipe.ingredients, multiplier);
    final materialCost = _consume(needed, operationId);
    final qty = recipe.yieldQty * multiplier;
    final total = materialCost == null || recipe.extraCost == null
        ? null
        : materialCost + recipe.extraCost! * multiplier;
    output.avgCost = movingAverageCost(
      oldQty: output.qty,
      oldAvg: output.avgCost,
      addQty: qty,
      addCost: total == null ? null : total / qty,
    );
    output.qty += qty;
    movements.add(
      StockMovement(
        id: newId('mv'),
        productId: output.id,
        type: MovementType.adjustment,
        qtyDelta: qty,
        unitCost: total == null ? null : total / qty,
        sourceId: operationId,
        date: now,
        createdAt: now,
      ),
    );
    productionRecords.add(
      ProductionRecord(operationId, recipe.id, qty, total, now),
    );
    await _save();
  }

  Future<void> recordWaste(Product product, double qty, String reason) async {
    _amount(qty, 'Jumlah terbuang', positive: true);
    if (qty > product.qty || reason.trim().isEmpty || !product.active) {
      throw StateError('Periksa jumlah stok dan isi alasan.');
    }
    final id = newId('waste');
    final cost = cogsFor(qty, product.avgCost);
    _consume({product.id: qty}, id);
    wasteRecords.add(
      WasteRecord(id, product.id, qty, cost, reason.trim(), now),
    );
    if (cost != null) {
      expenses.add(
        Expense(
          id: newId('exp'),
          date: now,
          description: '${product.name}: ${reason.trim()}',
          category: 'Barang terbuang',
          amount: cost,
          type: ExpenseType.businessExpense,
          createdAt: now,
        ),
      );
    }
    await _save();
  }

  Map<String, dynamic> get adviceContext {
    final since = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 29));
    bool inWindow(DateTime d) => !d.isBefore(since) && !d.isAfter(now);
    final s = summary(inWindow);
    final active = activeOrders;
    final facts = <Map<String, dynamic>>[];
    void fact(String id, String label, Object? value, [String unit = '']) =>
        facts.add({'id': id, 'label': label, 'value': value, 'unit': unit});
    fact('period_days', 'Periode catatan', 30, 'hari');
    fact(
      'confirmed_sales',
      'Penjualan / pekerjaan selesai dalam periode',
      s.saleCount,
      'catatan',
    );
    fact('revenue', 'Pendapatan terkonfirmasi dalam periode', s.revenue, 'Rp');
    fact('profit', 'Laba bersih perkiraan dalam periode', s.netProfit, 'Rp');
    fact('operating_costs', 'Biaya usaha dalam periode', s.opex, 'Rp');
    final en = languageCode == 'en';
    String label(String id, String english) => en ? english : id;
    fact('advice_focus', 'Advice policy', 'business_actions_v2');
    final focus =
        business?.understanding?['summary'] as String? ??
        business?.purpose ??
        '';
    fact(
      'business_focus',
      label('Kegiatan usaha terkonfirmasi', 'Confirmed business activities'),
      focus.length > 200 ? focus.substring(0, 200) : focus,
    );
    final recentStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));
    final previousStart = recentStart.subtract(const Duration(days: 7));
    bool recent(DateTime d) => !d.isBefore(recentStart) && !d.isAfter(now);
    bool previous(DateTime d) =>
        !d.isBefore(previousStart) && d.isBefore(recentStart);
    final performance = productPerformance(inWindow);
    final recentItems = {
      for (final i in productPerformance(recent)) i.productId: i,
    };
    final previousItems = {
      for (final i in productPerformance(previous)) i.productId: i,
    };
    for (final period in [true, false]) {
      final days = sales
          .where((s) => period ? recent(s.date) : previous(s.date))
          .map((s) => dayKey(s.date))
          .toSet()
          .length;
      fact(
        period ? 'recent_recorded_days' : 'previous_recorded_days',
        period
            ? label(
                'Hari dengan penjualan tercatat selama tujuh hari terakhir',
                'Days with recorded sales in the last seven days',
              )
            : label(
                'Hari dengan penjualan tercatat selama tujuh hari sebelumnya',
                'Days with recorded sales in the previous seven days',
              ),
        days,
        en ? 'days' : 'hari',
      );
    }
    // Four item summaries keep the full request below the sixty-fact limit.
    final selectedIds = <String>{
      ...performance
          .where((i) => productById(i.productId)?.isLowStock == true)
          .take(2)
          .map((i) => i.productId),
      ...performance.map((i) => i.productId),
      ...activeProducts.where((p) => p.isLowStock).map((p) => p.id),
    }.take(4);
    for (final id in selectedIds) {
      final safeId = id.replaceAll(RegExp('[^a-zA-Z0-9_]'), '_').toLowerCase();
      final key =
          'item_${safeId.length > 45 ? safeId.substring(0, 45) : safeId}';
      final p = productById(id);
      final matches = performance.where((i) => i.productId == id);
      final item = matches.isEmpty ? null : matches.first;
      final rawName = p?.name ?? item!.name;
      final name = rawName.length > 90 ? rawName.substring(0, 90) : rawName;
      final unit = p?.unit ?? '';
      fact(
        '${key}_revenue',
        label('Pendapatan tercatat: $name', 'Recorded revenue: $name'),
        item?.revenue ?? 0,
        'Rp',
      );
      fact(
        '${key}_cost',
        label('Harga pokok tercatat: $name', 'Recorded direct cost: $name'),
        item == null
            ? null
            : item.cogsComplete
            ? item.cogs
            : null,
        'Rp',
      );
      fact(
        '${key}_qty',
        label(
          'Jumlah terjual tercatat: $name',
          'Recorded quantity sold: $name',
        ),
        item?.qty ?? 0,
        unit,
      );
      fact(
        '${key}_recent_qty',
        label(
          'Terjual tercatat tujuh hari terakhir: $name',
          'Recorded sales, last seven days: $name',
        ),
        recentItems[id]?.qty ?? 0,
        unit,
      );
      fact(
        '${key}_previous_qty',
        label(
          'Terjual tercatat tujuh hari sebelumnya: $name',
          'Recorded sales, previous seven days: $name',
        ),
        previousItems[id]?.qty ?? 0,
        unit,
      );
      if (p != null) {
        fact(
          '${key}_stock',
          label('Stok saat ini: $name', 'Current stock: $name'),
          p.qty,
          unit,
        );
        fact(
          '${key}_minimum',
          label(
            'Stok minimum pilihan pemilik: $name',
            'Owner-set minimum stock: $name',
          ),
          p.minQty,
          unit,
        );
      }
    }
    for (var i = 0; i < offerings.length && i < 3; i++) {
      final o = offerings[i];
      final name = o.name.length > 80 ? o.name.substring(0, 80) : o.name;
      fact(
        'service_catalog_$i',
        label(
          'Tarif layanan tersedia: $name / ${o.unit}',
          'Available service price: $name / ${o.unit}',
        ),
        o.price,
        'Rp',
      );
    }
    final merchandise = activeProducts
        .where((p) => !p.materialOnly)
        .take(3)
        .toList();
    for (var i = 0; i < merchandise.length; i++) {
      final p = merchandise[i];
      final name = p.name.length > 90 ? p.name.substring(0, 90) : p.name;
      fact(
        'merchandise_$i',
        label('Barang untuk dijual: $name', 'Merchandise for sale: $name'),
        p.qty,
        p.unit,
      );
    }
    final expenseTotals = <String, double>{};
    for (final expense in expenses.where(
      (e) => inWindow(e.date) && e.type == ExpenseType.businessExpense,
    )) {
      expenseTotals.update(
        expense.category,
        (v) => v + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }
    final rankedExpenses = expenseTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (var i = 0; i < rankedExpenses.length && i < 3; i++) {
      final entry = rankedExpenses[i];
      final category = entry.key.length > 100
          ? entry.key.substring(0, 100)
          : entry.key;
      fact(
        'expense_category_$i',
        'Pengeluaran tercatat: $category',
        entry.value,
        'Rp',
      );
    }
    fact(
      'catalog_services',
      'Layanan yang sudah dibuat',
      offerings.length,
      'layanan',
    );
    fact(
      'catalog_products',
      'Produk / bahan yang sudah dicatat',
      activeProducts.length,
      'produk',
    );
    fact('active_orders', 'Pesanan belum selesai', active.length, 'pesanan');
    fact(
      'overdue_orders',
      'Pesanan melewati jadwal / tenggat',
      active.where((o) => o.dueAt.isBefore(now)).length,
      'pesanan',
    );
    fact(
      'ready_collection',
      'Pesanan siap diserahkan atau diambil',
      active.where((o) => o.status.startsWith('Siap')).length,
      'pesanan',
    );
    fact(
      'outstanding',
      'Sisa tagihan semua pesanan aktif / selesai',
      orderReceivables,
      'Rp',
    );
    fact(
      'deposits',
      'Saldo uang muka pada pekerjaan belum selesai',
      active.fold<double>(0, (a, o) => a + o.paid),
      'Rp',
    );
    fact(
      'unknown_order_costs',
      'Pesanan belum memiliki biaya langsung',
      orders.where((o) => !o.cancelled && o.directCost == null).length,
      'pesanan',
    );
    fact(
      'waste_events',
      'Catatan barang terbuang dalam periode',
      wasteRecords.where((r) => inWindow(r.at)).length,
      'catatan',
    );
    fact(
      'waste_cost',
      'Biaya barang terbuang yang sudah diketahui',
      wasteRecords
          .where((r) => inWindow(r.at))
          .fold<double>(0, (a, r) => a + (r.cost ?? 0)),
      'Rp',
    );
    fact(
      'unknown_waste',
      'Catatan terbuang tanpa harga modal',
      wasteRecords.where((r) => inWindow(r.at) && r.cost == null).length,
      'catatan',
    );
    if (hasGoods || activeProducts.isNotEmpty) {
      fact(
        'low_stock',
        'Produk / bahan di bawah stok minimum',
        activeProducts.where((p) => p.isLowStock).length,
        'produk',
      );
      fact(
        'missing_cost',
        'Produk / bahan tanpa harga modal',
        activeProducts.where((p) => p.avgCost == null).length,
        'produk',
      );
    }
    return {
      'business': businessContext,
      'facts': facts,
      'feedback': adviceFeedback.reversed
          .take(30)
          .map((f) => {'topic': f['topic'], 'useful': f['useful']})
          .toList(),
    };
  }

  bool get adviceStale => adviceContextSaved != jsonEncode(adviceContext);
  Future<void> refreshBusinessAdvice() async {
    if (adviceBusy) return;
    adviceBusy = true;
    adviceError = null;
    refresh();
    final businessId = business?.id;
    final context = adviceContext;
    try {
      if (advisor == null) {
        throw StateError('Hubungkan Google untuk meminta saran Gemini.');
      }
      final result = await advisor!.generate(context);
      if (business?.id != businessId) return;
      if (jsonEncode(adviceContext) != jsonEncode(context)) return;
      advice = result;
      adviceContextSaved = jsonEncode(context);
      await _save();
    } catch (e) {
      if (business?.id == businessId) {
        adviceError = e is StateError
            ? e.message
            : 'Arahan belum dapat dimuat. Coba lagi sebentar.';
      }
    } finally {
      adviceBusy = false;
      refresh();
      if (business?.id == businessId &&
          advisor != null &&
          adviceError == null &&
          jsonEncode(adviceContext) != jsonEncode(context)) {
        unawaited(refreshBusinessAdvice());
      }
    }
  }

  Future<void> rateBusinessAdvice(
    Map<String, dynamic> recommendation,
    bool useful,
  ) async {
    adviceFeedback.removeWhere((f) => f['id'] == recommendation['id']);
    adviceFeedback.add({
      'id': recommendation['id'],
      'topic': recommendation['topic'],
      'useful': useful,
      'at': now.toIso8601String(),
    });
    await _save();
  }
}
