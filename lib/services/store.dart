import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../utils/format.dart';
import 'ai_extractor.dart';
import 'cloud_extractor.dart';
import 'ledger.dart';
import 'google_services.dart';
import '../business_types.dart';
import '../operations_models.dart';
import 'personalization_client.dart';

part 'business_operations.dart';

/// XP rewards (configurable — PRD §11).
class XpRules {
  static const onboarding = 100;
  static const openingStock = 100;
  static const dailySales = 30;
  static const completedCost = 20;
  static const dailyMission = 50;
  static const aiMission = 100;
  static const xpPerLevel = 300;
}

class PostResult {
  final bool ok;
  final bool duplicate;
  final String message;
  final int xpGained;
  const PostResult({
    required this.ok,
    this.duplicate = false,
    required this.message,
    this.xpGained = 0,
  });
}

class ValidationReport {
  final List<String> errors;
  final List<String> warnings;
  final Map<int, String> rowErrors;
  ValidationReport(this.errors, this.warnings, this.rowErrors);
  bool get ok => errors.isEmpty && rowErrors.isEmpty;
}

/// Accepted AI-proposed mission (persisted so progress survives the insight
/// disappearing once the problem is fixed).
class AcceptedMission {
  final String id;
  final String kind; // 'restock'
  final String productId;
  final String createdDay;
  AcceptedMission(this.id, this.kind, this.productId, this.createdDay);
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'productId': productId,
    'createdDay': createdDay,
  };
  factory AcceptedMission.fromJson(Map<String, dynamic> j) =>
      AcceptedMission(j['id'], j['kind'], j['productId'], j['createdDay']);
}

/// Local, single-business app state. In production the posting methods are
/// Cloud Run endpoints running inside a Firestore transaction; here they run
/// as an all-or-nothing in-memory update followed by one persisted write.
class AppStore extends ChangeNotifier {
  static const _key = 'warungpilot_state_v1';

  final AiExtractor extractor;
  final GoogleServices? google;
  final PersonalizationClient? advisor;
  AppStore({AiExtractor? extractor, this.google, this.advisor})
    : extractor = extractor ?? DemoAiExtractor();
  List<Offering> offerings = [];
  List<WorkOrder> orders = [];
  List<ProductionRecipe> recipes = [];
  List<ProductionRecord> productionRecords = [];
  List<WasteRecord> wasteRecords = [];
  List<Map<String, dynamic>> adviceFeedback = [];
  BusinessAdvice? advice;
  String? adviceContextSaved;
  bool adviceBusy = false;
  String? adviceError;

  String? loadError;
  String? syncError;
  bool syncing = false;
  bool cloudPending = false;
  String? _uid;
  int _cloudRevision = 0;
  int _generation = 0;
  Future<void> _persistTail = Future.value();
  Future<void>? _syncTask;
  bool get googleEnabled => google != null;
  String get _storageKey => _uid == null ? _key : '${_key}_google_$_uid';

  bool loaded = false;
  String languageCode = 'id';
  bool languageChosen = false;
  Future<void> setLanguage(String code) async {
    if (code != 'id' && code != 'en') {
      throw ArgumentError.value(code, 'language');
    }
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString('retailee_language_v1', code);
    if (!saved) throw StateError('Could not save language preference.');
    if (languageCode != code) {
      advice = null;
      adviceContextSaved = null;
      adviceError = null;
    }
    languageCode = code;
    languageChosen = true;
    Intl.defaultLocale = code == 'en' ? 'en_US' : 'id_ID';
    notifyListeners();
  }

  String? userName;
  String? userEmail;
  Business? business;
  List<Product> products = [];
  List<StockMovement> movements = [];
  List<Sale> sales = [];
  List<Expense> expenses = [];
  List<SourceDocument> documents = [];
  List<XpEvent> xpEvents = [];
  List<AcceptedMission> acceptedMissions = [];
  OwnerAiProfile? profile; // owner_ai_profile (PRD §10.1)
  List<InsightFeedback> feedback = []; // insight_feedback
  final Map<String, Uint8List> _images = {}; // session-only photo cache
  final Map<String, Future<void>> _photoLoads = {};
  final Map<String, String> photoErrors = {};
  final Set<String> _extracting = {};
  bool photoLoading(String docId) => _photoLoads.containsKey(docId);
  final Set<String> _postingInFlight = {};

  DateTime Function() clock = DateTime.now;
  DateTime get now => clock();
  String get today => dayKey(now);

  bool get signedIn => userName != null;
  bool get onboarded => business != null;

  // ---------------------------------------------------------------- persist
  Future<void> load() async {
    loaded = false;
    loadError = null;
    syncError = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguage = prefs.getString('retailee_language_v1');
      languageChosen = savedLanguage == 'id' || savedLanguage == 'en';
      languageCode = savedLanguage == 'en' ? 'en' : 'id';
      Intl.defaultLocale = languageCode == 'en' ? 'en_US' : 'id_ID';
      _uid = google?.auth.currentUser?.uid;
      _fromJson({});
      _images.clear();
      _attemptMap.clear();
      cloudPending = false;
      _cloudRevision = 0;
      // A Firebase session, rather than a saved display name, proves login.
      if (google != null && _uid == null) {
        loaded = true;
        notifyListeners();
        return;
      }
      final raw = prefs.getString(_storageKey);
      if (raw != null) _fromJson(jsonDecode(raw));
      if (google != null) {
        final local = raw == null
            ? <String, dynamic>{}
            : jsonDecode(raw) as Map<String, dynamic>;
        _cloudRevision = local['_cloudRevision'] as int? ?? 0;
        cloudPending = local['_cloudPending'] == true;
        if (!cloudPending) {
          try {
            final remote = await google!.read(_uid!);
            if (remote.state != null) {
              _fromJson(remote.state!);
            } else if (raw != null && _cloudRevision != 0) {
              throw StateError(
                'Cadangan cloud tidak ditemukan. Data lokal dipertahankan.',
              );
            }
            _cloudRevision = remote.revision;
          } catch (e) {
            if (raw == null) rethrow;
            syncError = 'Cloud belum dapat dibaca. Data lokal tersedia. $e';
          }
        }
        final user = google!.auth.currentUser!;
        userName = user.displayName ?? user.email ?? 'Pemilik Usaha';
        userEmail = user.email;
        await _persistLocal();
      }
    } catch (e) {
      loadError = 'Data belum dapat dimuat. $e';
    }
    loaded = true;
    notifyListeners();
    if (loadError == null && cloudPending) unawaited(syncCloud());
  }

  Future<void> _persistLocal() {
    final key = _storageKey;
    final raw = jsonEncode({
      ..._toJson(),
      '_cloudRevision': _cloudRevision,
      '_cloudPending': cloudPending,
    });
    final task = _persistTail.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(key, raw)) {
        throw StateError('Penyimpanan perangkat penuh.');
      }
    });
    _persistTail = task.catchError((Object _) {});
    return task;
  }

  Future<void> _save() async {
    _generation++;
    if (_uid != null) cloudPending = true;
    await _persistLocal();
    notifyListeners();
    if (_uid != null) unawaited(syncCloud());
  }

  Future<void> syncCloud() {
    if (_syncTask != null) return _syncTask!;
    final task = _syncCloud();
    _syncTask = task;
    return task.whenComplete(() => _syncTask = null);
  }

  Future<void> _syncCloud() async {
    if (google == null || _uid == null || !cloudPending) return;
    syncing = true;
    syncError = null;
    notifyListeners();
    try {
      while (cloudPending) {
        final generation = _generation;
        final snapshot =
            jsonDecode(jsonEncode(_toJson())) as Map<String, dynamic>;
        _cloudRevision = await google!.write(_uid!, snapshot, _cloudRevision);
        cloudPending = generation != _generation;
        await _persistLocal();
      }
    } catch (e) {
      syncError = 'Cadangan belum terkirim. Data tersimpan di perangkat. $e';
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Map<String, dynamic> _toJson() => {
    'userName': userName,
    'userEmail': userEmail,
    'business': business?.toJson(),
    'products': products.map((e) => e.toJson()).toList(),
    'movements': movements.map((e) => e.toJson()).toList(),
    'sales': sales.map((e) => e.toJson()).toList(),
    'expenses': expenses.map((e) => e.toJson()).toList(),
    'documents': documents.map((e) => e.toJson()).toList(),
    'xpEvents': xpEvents.map((e) => e.toJson()).toList(),
    'acceptedMissions': acceptedMissions.map((e) => e.toJson()).toList(),
    'profile': profile?.toJson(),
    'feedback': feedback.map((e) => e.toJson()).toList(),
    'offerings': offerings.map((e) => e.toJson()).toList(),
    'orders': orders.map((e) => e.toJson()).toList(),
    'recipes': recipes.map((e) => e.toJson()).toList(),
    'productionRecords': productionRecords.map((e) => e.toJson()).toList(),
    'wasteRecords': wasteRecords.map((e) => e.toJson()).toList(),
    'adviceFeedback': adviceFeedback,
    'businessAdvice': advice?.toJson(),
    'adviceContextSaved': adviceContextSaved,
  };

  void _fromJson(Map<String, dynamic> j) {
    offerings = (j['offerings'] as List? ?? [])
        .map((e) => Offering.fromJson(e))
        .toList();
    orders = (j['orders'] as List? ?? [])
        .map((e) => WorkOrder.fromJson(e))
        .toList();
    recipes = (j['recipes'] as List? ?? [])
        .map((e) => ProductionRecipe.fromJson(e))
        .toList();
    productionRecords = (j['productionRecords'] as List? ?? [])
        .map((e) => ProductionRecord.fromJson(e))
        .toList();
    wasteRecords = (j['wasteRecords'] as List? ?? [])
        .map((e) => WasteRecord.fromJson(e))
        .toList();
    adviceFeedback = (j['adviceFeedback'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    advice = j['businessAdvice'] == null
        ? null
        : BusinessAdvice.fromJson(j['businessAdvice']);
    adviceContextSaved = j['adviceContextSaved'];
    if (adviceContextSaved != null) {
      final savedContext =
          jsonDecode(adviceContextSaved!) as Map<String, dynamic>;
      final savedLanguage =
          (savedContext['business'] as Map?)?['language'] ?? 'id';
      final currentAdvicePolicy = (savedContext['facts'] as List? ?? []).any(
        (f) => f['id'] == 'advice_focus' && f['value'] == 'business_actions_v2',
      );
      if (savedLanguage != languageCode || !currentAdvicePolicy) {
        advice = null;
        adviceContextSaved = null;
      }
    }
    adviceError = null;
    userName = j['userName'];
    userEmail = j['userEmail'];
    business = j['business'] == null ? null : Business.fromJson(j['business']);
    products = (j['products'] as List? ?? [])
        .map((e) => Product.fromJson(e))
        .toList();
    movements = (j['movements'] as List? ?? [])
        .map((e) => StockMovement.fromJson(e))
        .toList();
    sales = (j['sales'] as List? ?? []).map((e) => Sale.fromJson(e)).toList();
    expenses = (j['expenses'] as List? ?? [])
        .map((e) => Expense.fromJson(e))
        .toList();
    documents = (j['documents'] as List? ?? [])
        .map((e) => SourceDocument.fromJson(e))
        .toList();
    xpEvents = (j['xpEvents'] as List? ?? [])
        .map((e) => XpEvent.fromJson(e))
        .toList();
    acceptedMissions = (j['acceptedMissions'] as List? ?? [])
        .map((e) => AcceptedMission.fromJson(e))
        .toList();
    profile = j['profile'] == null
        ? null
        : OwnerAiProfile.fromJson(j['profile']);
    feedback = (j['feedback'] as List? ?? [])
        .map((e) => InsightFeedback.fromJson(e))
        .toList();
    if (business != null && profile == null) {
      profile = OwnerAiProfile(updatedAt: now);
    }
    // Drafts interrupted mid-processing are recoverable as failed drafts.
    for (final d in documents.where((d) => d.status == DocStatus.processing)) {
      d.status = DocStatus.failed;
      d.error = 'Proses terhenti. Silakan proses ulang.';
    }
  }

  void refresh() => notifyListeners();

  Future<void> resetAll() async {
    if (googleEnabled) {
      throw StateError('Reset demo tidak tersedia untuk akun Google.');
    }
    userName = null;
    userEmail = null;
    business = null;
    products = [];
    movements = [];
    sales = [];
    expenses = [];
    documents = [];
    xpEvents = [];
    acceptedMissions = [];
    profile = null;
    feedback = [];
    offerings = [];
    orders = [];
    recipes = [];
    productionRecords = [];
    wasteRecords = [];
    advice = null;
    adviceContextSaved = null;
    adviceFeedback = [];
    _images.clear();
    await _save();
  }

  // ------------------------------------------------------------------ auth
  /// Demo stand-in for Google Sign-In (Firebase Auth not configured yet).
  Future<void> signInDemo() async {
    if (googleEnabled) throw StateError('Gunakan masuk dengan Google.');
    await Future.delayed(const Duration(milliseconds: 700));
    userName = 'Pemilik Warung';
    userEmail = 'demo@warungpilot.app';
    await _save();
  }

  Future<void> signOut() async {
    if (google != null) {
      if (_extracting.isNotEmpty) {
        throw StateError('Tunggu pembacaan foto selesai sebelum keluar.');
      }
      await _syncTask;
      await google!.signOut();
      _uid = null;
      _fromJson({});
      _images.clear();
      _attemptMap.clear();
      cloudPending = false;
      syncError = null;
      loadError = null;
      notifyListeners();
      return;
    }
    userName = null;
    await _save();
  }

  Future<void> signIn() async {
    if (google == null) return signInDemo();
    await google!.signIn();
    await load();
    if (loadError != null) throw StateError(loadError!);
  }

  Future<void> restoreCloud() async {
    if (google == null || _uid == null) return;
    await _syncTask;
    final snapshot = await google!.read(_uid!);
    if (snapshot.state == null) throw StateError('Belum ada cadangan cloud.');
    _fromJson(snapshot.state!);
    _images.clear();
    _attemptMap.clear();
    _cloudRevision = snapshot.revision;
    cloudPending = false;
    syncError = null;
    await _persistLocal();
    notifyListeners();
  }

  // ------------------------------------------------------------ onboarding
  Future<void> createBusiness({
    required String name,
    required String owner,
    required String city,
    OwnerGoal goal = OwnerGoal.stockAvailability,
    ExplainStyle style = ExplainStyle.concise,
    BusinessType? type,
    String subtype = '',
    String purpose = '',
    String pricingUnit = 'unit',
    String priority = '',
  }) async {
    if (business != null) return; // one user = one business
    business = Business(
      id: newId('biz'),
      name: name,
      ownerName: owner,
      city: city,
      createdAt: now,
      type: type,
      subtype: subtype,
      purpose: purpose,
      pricingUnit: pricingUnit,
      priority: priority,
    );
    profile = OwnerAiProfile(goal: goal, style: style, updatedAt: now);
    if (owner.isNotEmpty) userName = owner;
    _award('onboarding', 'Warung terdaftar', XpRules.onboarding);
    await _save();
  }

  // ------------------------------------------------------------------- XP
  int get totalXp => xpEvents.fold(0, (s, e) => s + e.xp);
  int get level => totalXp ~/ XpRules.xpPerLevel + 1;
  double get levelProgress =>
      (totalXp % XpRules.xpPerLevel) / XpRules.xpPerLevel;
  int get xpToNext => XpRules.xpPerLevel - totalXp % XpRules.xpPerLevel;
  bool hasAward(String key) => xpEvents.any((e) => e.key == key);

  /// Awards XP once per key. Returns XP gained (0 if already awarded).
  int _award(String key, String label, int xp) {
    if (hasAward(key)) return 0;
    xpEvents.add(XpEvent(key: key, label: label, xp: xp, at: now));
    return xp;
  }

  // ------------------------------------------------------------- products
  Product? productById(String? id) {
    if (id == null) return null;
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  List<Product> get activeProducts =>
      products.where((p) => p.active).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  List<Product> get sellableProducts =>
      activeProducts.where((p) => !p.materialOnly).toList();

  Future<int> addProductManual({
    required String name,
    required String unit,
    required String category,
    required double sellPrice,
    double? cost,
    required double qty,
    required double minQty,
    bool materialOnly = false,
  }) async {
    if (name.trim().isEmpty ||
        unit.trim().isEmpty ||
        !sellPrice.isFinite ||
        sellPrice < 0 ||
        (!materialOnly && sellPrice == 0) ||
        !qty.isFinite ||
        qty < 0 ||
        !minQty.isFinite ||
        minQty < 0 ||
        (cost != null && (!cost.isFinite || cost < 0))) {
      throw StateError('Periksa nama, satuan, harga dan jumlah stok.');
    }
    final p = Product(
      id: newId('prd'),
      name: name.trim(),
      unit: unit,
      category: category,
      sellPrice: sellPrice,
      avgCost: cost,
      qty: qty,
      minQty: minQty,
      materialOnly: materialOnly,
    );
    products.add(p);
    if (qty > 0) {
      movements.add(
        StockMovement(
          id: newId('mv'),
          productId: p.id,
          type: MovementType.opening,
          qtyDelta: qty,
          unitCost: cost,
          sourceId: 'manual',
          date: now,
          createdAt: now,
        ),
      );
    }
    final gained = _award(
      'opening_stock',
      'Stok awal tercatat',
      XpRules.openingStock,
    );
    await _save();
    return gained;
  }

  /// Edits descriptive fields. Cost can only be *completed* here (null → value);
  /// changing a known average requires a purchase or adjustment.
  Future<int> updateProduct(
    Product p, {
    String? name,
    double? sellPrice,
    double? minQty,
    String? category,
    String? unit,
    double? completeCost,
  }) async {
    var gained = 0;
    if (name != null && name.trim().isNotEmpty) p.name = name.trim();
    if (sellPrice != null) p.sellPrice = sellPrice;
    if (minQty != null) p.minQty = minQty;
    if (category != null) p.category = category;
    if (unit != null) p.unit = unit;
    if (completeCost != null && p.avgCost == null && completeCost > 0) {
      p.avgCost = completeCost;
      movements.add(
        StockMovement(
          id: newId('mv'),
          productId: p.id,
          type: MovementType.adjustment,
          qtyDelta: 0,
          unitCost: completeCost,
          sourceId: 'cost_completion',
          date: now,
          createdAt: now,
        ),
      );
      gained = _award(
        'cost_${p.id}',
        'Harga modal ${p.name} dilengkapi',
        XpRules.completedCost,
      );
    }
    await _save();
    return gained;
  }

  Future<void> restock(
    Product p, {
    required double qty,
    double? unitCost,
    String sourceId = 'manual',
  }) async {
    _applyPurchase(p, qty, unitCost, sourceId, now);
    await _save();
  }

  void _applyPurchase(
    Product p,
    double qty,
    double? unitCost,
    String sourceId,
    DateTime date,
  ) {
    p.avgCost = movingAverageCost(
      oldQty: p.qty,
      oldAvg: p.avgCost,
      addQty: qty,
      addCost: unitCost,
    );
    p.qty += qty;
    movements.add(
      StockMovement(
        id: newId('mv'),
        productId: p.id,
        type: MovementType.purchase,
        qtyDelta: qty,
        unitCost: unitCost,
        sourceId: sourceId,
        date: date,
        createdAt: now,
      ),
    );
  }

  Future<void> adjustStock(Product p, double newQty) async {
    final delta = newQty - p.qty;
    if (delta == 0) return;
    p.qty = newQty;
    movements.add(
      StockMovement(
        id: newId('mv'),
        productId: p.id,
        type: MovementType.adjustment,
        qtyDelta: delta,
        unitCost: p.avgCost,
        sourceId: 'manual_adjustment',
        date: now,
        createdAt: now,
      ),
    );
    await _save();
  }

  List<StockMovement> movementsFor(String productId) =>
      movements.where((m) => m.productId == productId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  // ------------------------------------------------------------ documents
  SourceDocument? documentById(String id) {
    for (final d in documents) {
      if (d.id == id) return d;
    }
    return null;
  }

  Uint8List? imageFor(String docId) => _images[docId];

  Future<void> loadPhoto(String docId) {
    if (_images.containsKey(docId)) return Future.value();
    final inFlight = _photoLoads[docId];
    if (inFlight != null) return inFlight;
    final doc = documentById(docId);
    if (doc == null ||
        doc.imagePath == null ||
        google == null ||
        _uid == null) {
      return Future.value();
    }
    final uid = _uid!;
    final task = _downloadPhoto(doc, uid);
    _photoLoads[docId] = task;
    notifyListeners();
    return task.whenComplete(() {
      if (identical(_photoLoads[docId], task)) _photoLoads.remove(docId);
      notifyListeners();
    });
  }

  Future<void> _downloadPhoto(SourceDocument doc, String uid) async {
    photoErrors.remove(doc.id);
    try {
      final image = await google!.downloadPhoto(uid, doc.id);
      if (_uid == uid &&
          identical(documentById(doc.id), doc) &&
          doc.status != DocStatus.cancelled) {
        _images[doc.id] = image;
      }
    } catch (_) {
      if (_uid == uid && identical(documentById(doc.id), doc)) {
        photoErrors[doc.id] =
            'Foto belum dapat diambil dari cloud. Periksa koneksi atau ambil foto ulang jika belum pernah terunggah.';
      }
    }
  }

  List<SourceDocument> get openDrafts =>
      documents
          .where(
            (d) => d.status == DocStatus.draft || d.status == DocStatus.failed,
          )
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Future<SourceDocument> createDocument(
    DocKind kind, {
    Uint8List? image,
    String? imagePath,
  }) async {
    if (google != null && image != null) {
      if (image.isEmpty || image.length > GoogleServices.maxPhotoBytes) {
        throw StateError(
          'Foto terlalu besar. Gunakan foto berukuran maksimal 6 MB.',
        );
      }
      GoogleServices.photoMime(image);
    }
    final doc = SourceDocument(
      id: newId('doc'),
      kind: kind,
      status: DocStatus.processing,
      date: now,
      saleMode: kind == DocKind.serviceIncome
          ? SaleMode.individual
          : SaleMode.dailySummary,
      imagePath: imagePath ?? (image == null ? null : 'foto'),
      createdAt: now,
    );
    if (image != null) _images[doc.id] = image;
    documents.add(doc);
    await _save();
    return doc;
  }

  int _attempts(String docId) => _attemptMap[docId] ?? 0;
  final Map<String, int> _attemptMap = {};

  /// Runs (or re-runs) AI extraction on a draft. Never touches business data.
  Future<void> extract(String docId) async {
    final doc = documentById(docId);
    if (doc == null ||
        doc.status == DocStatus.posted ||
        doc.status == DocStatus.cancelled ||
        !_extracting.add(docId)) {
      return;
    }
    bool active() =>
        identical(documentById(docId), doc) &&
        doc.status != DocStatus.cancelled;
    doc.status = DocStatus.processing;
    doc.error = null;
    notifyListeners();
    final attempt = _attempts(docId) + 1;
    _attemptMap[docId] = attempt;
    try {
      if (doc.imagePath != null &&
          !_images.containsKey(docId) &&
          google != null) {
        await loadPhoto(docId);
        if (!active()) return;
      }
      if (doc.imagePath != null && !_images.containsKey(docId)) {
        throw ExtractionException(
          photoErrors[docId] ??
              'Foto asli tidak tersedia. Foto ulang atau isi manual; data contoh tidak dipakai.',
        );
      }
      if (doc.imagePath != null && google != null && !doc.photoStored) {
        await google!.uploadPhoto(_uid!, doc.id, _images[docId]!);
        if (!active()) return;
        doc.photoStored = true;
        await _save();
        if (!active()) return;
      }
      final res = await extractor.extract(
        kind: doc.kind,
        image: _images[docId],
        catalog: doc.kind == DocKind.serviceIncome
            ? []
            : doc.kind == DocKind.dailySales
            ? sellableProducts
            : activeProducts,
        attempt: attempt,
      );
      if (!active()) return;
      doc.manualEntry = false;
      doc.servicesCompleted = false;
      doc.rawRows = res.rows.map((r) => r.copy()).toList();
      doc.rows = res.rows;
      doc.expense = res.expense;
      if (res.date != null) doc.date = res.date!;
      if (doc.expense != null) {
        doc.expense!.flags = _expenseFlags(doc.expense!, doc.id);
      }
      doc.status = DocStatus.draft;
    } catch (e) {
      if (!active()) return;
      doc.status = DocStatus.failed;
      doc.error = e.toString();
    } finally {
      _extracting.remove(docId);
    }
    await _save();
  }

  /// Empty draft for manual entry (recovery path when AI fails).
  Future<void> startManualDraft(String docId) async {
    final doc = documentById(docId);
    if (doc == null) return;
    doc.status = DocStatus.draft;
    doc.manualEntry = true;
    doc.error = null;
    if (doc.kind == DocKind.expenseReceipt) {
      doc.expense = DraftExpense(
        description: '',
        category: 'Lainnya',
        amount: 0,
        type: ExpenseType.businessExpense,
      );
    } else {
      doc.rows = [
        DraftRow(
          rawText: '(input manual)',
          name: '',
          qty: 1,
          unit: doc.kind == DocKind.serviceIncome
              ? business?.pricingUnit ?? 'unit'
              : 'unit',
        ),
      ];
    }
    await _save();
  }

  /// Demo only: makes the next extraction fail to show the recovery flow.
  void simulateNextFailure() {
    final e = extractor;
    if (e is DemoAiExtractor) e.simulateFailure = true;
    if (e is CloudRunAiExtractor) e.simulateFailure = true;
  }

  Future<void> saveDraft(SourceDocument doc) => _save();

  Future<void> cancelDocument(String docId) async {
    final doc = documentById(docId);
    if (doc == null || doc.status == DocStatus.posted) return;
    doc.status = DocStatus.cancelled;
    _images.remove(docId);
    photoErrors.remove(docId);
    await _save();
  }

  List<String> _expenseFlags(DraftExpense e, String docId) {
    final flags = <String>[];
    final dup = expenses.any(
      (x) =>
          x.amount == e.amount &&
          x.description.toLowerCase() == e.description.toLowerCase() &&
          now.difference(x.date).inDays.abs() <= 7,
    );
    if (dup) {
      flags.add(
        'Kemungkinan struk ganda: nominal & deskripsi sama dalam 7 hari terakhir.',
      );
    }
    final personal = RegExp(
      r'(pribadi|anak|sekolah|rokok pribadi|arisan)',
      caseSensitive: false,
    );
    if (personal.hasMatch(e.description)) {
      flags.add('Terlihat seperti pengeluaran pribadi.');
    }
    if (e.amount >= 2000000) {
      flags.add(
        'Nominal besar — mungkin pembelian aset (bukan biaya bulanan).',
      );
    }
    return flags;
  }

  // ----------------------------------------------------------- validation
  String rowUnit(DraftRow row) {
    final written = row.unit.trim();
    if (written.isEmpty || written == 'unit') {
      return productById(row.productId)?.unit ?? 'unit';
    }
    return written;
  }

  bool _rowUnitMatches(DraftRow row) {
    final product = productById(row.productId);
    return product == null ||
        normalizedUnit(rowUnit(row)) == normalizedUnit(product.unit);
  }

  ValidationReport validate(
    SourceDocument doc, {
    bool overlapAcknowledged = false,
  }) {
    final errors = <String>[];
    final warnings = <String>[];
    final rowErrors = <int, String>{};

    if (doc.kind == DocKind.expenseReceipt) {
      final e = doc.expense;
      if (e == null) {
        errors.add('Data biaya kosong.');
      } else {
        if (e.description.trim().isEmpty) errors.add('Isi keterangan biaya.');
        if (e.amount <= 0) errors.add('Nominal harus lebih dari 0.');
        if (e.type == ExpenseType.inventoryPurchase) {
          final r = doc.rows.isNotEmpty ? doc.rows.first : null;
          if (r == null ||
              productById(r.productId) == null ||
              !r.qty.isFinite ||
              r.qty <= 0) {
            errors.add('Pembelian stok: pilih produk dan jumlahnya.');
          } else if (!_rowUnitMatches(r)) {
            errors.add(
              'Satuan berbeda dari produk. Periksa jumlah dan satuannya.',
            );
          }
        }
      }
      return ValidationReport(errors, warnings, rowErrors);
    }

    final included = <int>[];
    for (var i = 0; i < doc.rows.length; i++) {
      if (doc.rows[i].include) included.add(i);
    }
    if (included.isEmpty) errors.add('Tidak ada baris yang dipilih.');

    if (doc.kind == DocKind.serviceIncome) {
      if (!doc.servicesCompleted) {
        errors.add(
          'Konfirmasi bahwa layanan sudah selesai. Uang muka bukan pendapatan layanan selesai.',
        );
      }
      for (final i in included) {
        final r = doc.rows[i];
        if (r.name.trim().isEmpty || r.unit.trim().isEmpty) {
          rowErrors[i] = 'Nama layanan wajib diisi';
        } else if (!r.qty.isFinite || r.qty <= 0) {
          rowErrors[i] = 'Jumlah harus > 0';
        } else if (r.unitPrice == null ||
            !r.unitPrice!.isFinite ||
            r.unitPrice! <= 0) {
          rowErrors[i] = 'Tarif layanan wajib diisi';
        } else if (r.unitCost != null &&
            (!r.unitCost!.isFinite || r.unitCost! < 0)) {
          rowErrors[i] = 'Biaya tidak valid';
        }
        if (r.unitCost == null) {
          warnings.add(
            'Biaya langsung belum lengkap. Laba belum bisa dipastikan.',
          );
        }
      }
      try {
        _materialNeeds([for (final i in included) ...doc.rows[i].materials]);
      } catch (e) {
        errors.add(e.toString());
      }
    }

    if (doc.kind == DocKind.openingStock) {
      for (final i in included) {
        final r = doc.rows[i];
        if (r.name.trim().isEmpty && r.productId == null) {
          rowErrors[i] = 'Nama produk wajib diisi';
        } else if (!r.qty.isFinite || r.qty < 0) {
          rowErrors[i] = 'Jumlah tidak boleh negatif';
        } else if (!_rowUnitMatches(r)) {
          rowErrors[i] =
              'Satuan berbeda dari produk. Periksa jumlah dan satuannya.';
        } else if (r.unit.trim().isEmpty) {
          rowErrors[i] = 'Isi satuan produk.';
        } else if (r.productId == null && (r.unitPrice ?? 0) <= 0) {
          rowErrors[i] = 'Harga jual wajib diisi';
        }
        if (r.unitCost == null) {
          warnings.add(
            '${r.name.isEmpty ? 'Baris ${i + 1}' : r.name}: harga modal kosong — laba akan ditandai belum lengkap.',
          );
        }
      }
    }

    if (doc.kind == DocKind.dailySales) {
      final need = <String, double>{};
      for (final i in included) {
        final r = doc.rows[i];
        if (productById(r.productId) == null) {
          rowErrors[i] = 'Pilih produk yang cocok';
          continue;
        }
        if (productById(r.productId)?.materialOnly == true) {
          rowErrors[i] =
              'Bahan habis pakai dicatat melalui layanan atau pesanan.';
          continue;
        }
        if (!_rowUnitMatches(r)) {
          rowErrors[i] =
              'Satuan berbeda dari produk. Periksa jumlah dan satuannya.';
          continue;
        }
        if (!r.qty.isFinite || r.qty <= 0) {
          rowErrors[i] = 'Jumlah harus > 0';
          continue;
        }
        if (!(r.unitPrice ?? 0).isFinite || (r.unitPrice ?? 0) <= 0) {
          rowErrors[i] = 'Harga satuan wajib diisi';
          continue;
        }
        need[r.productId!] = (need[r.productId!] ?? 0) + r.qty;
      }
      need.forEach((pid, q) {
        final p = productById(pid);
        if (p != null && q > p.qty) {
          for (final i in included) {
            if (doc.rows[i].productId == pid) {
              rowErrors[i] = 'Stok ${p.name} hanya ${fmtQty(p.qty)} ${p.unit}';
            }
          }
        }
      });
      for (final i in included) {
        final p = productById(doc.rows[i].productId);
        if (p != null && p.avgCost == null) {
          warnings.add(
            '${p.name}: harga modal belum ada — HPP & laba ditandai belum lengkap.',
          );
        }
      }
    }
    if (doc.kind == DocKind.dailySales || doc.kind == DocKind.serviceIncome) {
      // Source coverage / overlap rules (PRD §7)
      final d = dayKey(doc.date);
      final sameDay = sales.where((s) => dayKey(s.date) == d).toList();
      final hasSummary = sameDay.any((s) => s.mode == SaleMode.dailySummary);
      final hasIndividual = sameDay.any((s) => s.mode == SaleMode.individual);
      if (hasSummary) {
        errors.add(
          'Ringkasan harian ${fmtDate(doc.date)} sudah tercatat. '
          'Mencatat lagi akan menghitung penjualan dua kali.',
        );
      } else if (doc.saleMode == SaleMode.dailySummary &&
          hasIndividual &&
          !overlapAcknowledged) {
        errors.add(
          'Sudah ada transaksi satuan pada ${fmtDate(doc.date)}. '
          'Pastikan ringkasan ini TIDAK mencakup transaksi tersebut.',
        );
      }
    }
    return ValidationReport(errors, warnings, rowErrors);
  }

  bool needsOverlapAck(SourceDocument doc) {
    if ((doc.kind != DocKind.dailySales && doc.kind != DocKind.serviceIncome) ||
        doc.saleMode != SaleMode.dailySummary) {
      return false;
    }
    final d = dayKey(doc.date);
    final sameDay = sales.where((s) => dayKey(s.date) == d);
    return sameDay.any((s) => s.mode == SaleMode.individual) &&
        !sameDay.any((s) => s.mode == SaleMode.dailySummary);
  }

  // -------------------------------------------------------------- posting
  /// Explicit-confirmation posting. Idempotent on the document id.
  Future<PostResult> confirmDocument(
    String docId, {
    bool overlapAcknowledged = false,
  }) async {
    final doc = documentById(docId);
    if (doc == null) {
      return const PostResult(ok: false, message: 'Dokumen tidak ditemukan.');
    }
    if (doc.status == DocStatus.posted ||
        sales.any((s) => s.idempotencyKey == docId)) {
      return const PostResult(
        ok: true,
        duplicate: true,
        message: 'Dokumen ini sudah pernah dicatat.',
      );
    }
    if (doc.status != DocStatus.draft) {
      return const PostResult(
        ok: false,
        message: 'Hanya draf yang bisa dikonfirmasi.',
      );
    }
    if (!_postingInFlight.add(docId)) {
      return const PostResult(
        ok: true,
        duplicate: true,
        message: 'Sedang diproses…',
      );
    }
    try {
      final v = validate(doc, overlapAcknowledged: overlapAcknowledged);
      if (!v.ok) {
        return PostResult(
          ok: false,
          message: [...v.errors, ...v.rowErrors.values].first,
        );
      }
      var xp = 0;
      final refs = <String>[];
      switch (doc.kind) {
        case DocKind.serviceIncome:
          final items = <SaleItem>[];
          // Validate combined consumption before any inventory mutations.
          _materialNeeds([
            for (final r in doc.rows.where((r) => r.include)) ...r.materials,
          ]);
          for (final r in doc.rows.where((r) => r.include)) {
            final materialCost = _consume(
              _materialNeeds(r.materials),
              doc.id,
              doc.date,
            );
            items.add(
              SaleItem(
                productId: 'service_${doc.id}_${items.length}',
                productName: r.name.trim(),
                unit: r.unit.trim(),
                qty: r.qty,
                unitPrice: r.unitPrice!,
                cogs: materialCost == null || r.unitCost == null
                    ? null
                    : materialCost + r.unitCost! * r.qty,
              ),
            );
          }
          final serviceSale = Sale(
            id: newId('sale'),
            date: doc.date,
            mode: doc.saleMode,
            items: items,
            idempotencyKey: doc.id,
            documentId: doc.id,
            createdAt: now,
          );
          sales.add(serviceSale);
          refs.add(serviceSale.id);
          break;
        case DocKind.openingStock:
          for (final r in doc.rows.where((r) => r.include)) {
            final existing = productById(r.productId);
            if (existing != null) {
              _applyPurchase(existing, r.qty, r.unitCost, doc.id, doc.date);
              refs.add(existing.id);
            } else {
              final p = Product(
                id: newId('prd'),
                name: r.name.trim(),
                sellPrice: r.unitPrice ?? 0,
                avgCost: r.unitCost,
                qty: r.qty,
                minQty: 5,
                category: 'Sembako & minuman',
                unit: rowUnit(r),
              );
              products.add(p);
              movements.add(
                StockMovement(
                  id: newId('mv'),
                  productId: p.id,
                  type: MovementType.opening,
                  qtyDelta: r.qty,
                  unitCost: r.unitCost,
                  sourceId: doc.id,
                  date: doc.date,
                  createdAt: now,
                ),
              );
              refs.add(p.id);
            }
          }
          xp += _award(
            'opening_stock',
            'Stok awal tercatat',
            XpRules.openingStock,
          );
          break;
        case DocKind.dailySales:
          final saleId = newId('sale');
          final items = <SaleItem>[];
          for (final r in doc.rows.where((r) => r.include)) {
            final p = productById(r.productId)!;
            final cogs = cogsFor(r.qty, p.avgCost);
            items.add(
              SaleItem(
                productId: p.id,
                productName: p.name,
                unit: p.unit,
                qty: r.qty,
                unitPrice: r.unitPrice!,
                cogs: cogs,
              ),
            );
            p.qty -= r.qty;
            movements.add(
              StockMovement(
                id: newId('mv'),
                productId: p.id,
                type: MovementType.sale,
                qtyDelta: -r.qty,
                unitCost: p.avgCost,
                sourceId: saleId,
                date: doc.date,
                createdAt: now,
              ),
            );
          }
          sales.add(
            Sale(
              id: saleId,
              date: doc.date,
              mode: doc.saleMode,
              items: items,
              idempotencyKey: doc.id,
              documentId: doc.id,
              createdAt: now,
            ),
          );
          refs.add(saleId);
          _learnAliases(doc);
          final d = dayKey(doc.date);
          xp += _award(
            'sales_$d',
            'Penjualan ${fmtDate(doc.date)} tercatat',
            XpRules.dailySales,
          );
          break;
        case DocKind.expenseReceipt:
          final e = doc.expense!;
          if (e.type == ExpenseType.inventoryPurchase) {
            final r = doc.rows.first;
            final p = productById(r.productId)!;
            _applyPurchase(p, r.qty, e.amount / r.qty, doc.id, doc.date);
          }
          final ex = Expense(
            id: newId('exp'),
            date: doc.date,
            description: e.description,
            category: e.category,
            amount: e.amount,
            vendor: e.vendor,
            type: e.type,
            documentId: doc.id,
            createdAt: now,
          );
          expenses.add(ex);
          refs.add(ex.id);
          break;
      }
      doc.status = DocStatus.posted;
      doc.postedRefs = refs;
      _images.remove(doc.id);
      await _save();
      if (advisor != null) unawaited(refreshBusinessAdvice());
      return PostResult(ok: true, message: 'Berhasil dicatat.', xpGained: xp);
    } finally {
      _postingInFlight.remove(docId);
    }
  }

  Future<void> addExpenseManual({
    required String description,
    required String category,
    required double amount,
    required ExpenseType type,
    String? vendor,
    DateTime? date,
  }) async {
    expenses.add(
      Expense(
        id: newId('exp'),
        date: date ?? now,
        description: description,
        category: category,
        amount: amount,
        vendor: vendor,
        type: type,
        createdAt: now,
      ),
    );
    await _save();
  }

  // ------------------------------------------------------------ reporting
  PeriodSummary summary(bool Function(DateTime) inPeriod) {
    final s = sales.where((x) => inPeriod(x.date)).toList();
    final e = expenses.where((x) => inPeriod(x.date)).toList();
    double sum(Iterable<Expense> xs) => xs.fold(0, (a, b) => a + b.amount);
    return PeriodSummary(
      revenue: s.fold(0, (a, b) => a + b.revenue),
      knownCogs: s.fold(0, (a, b) => a + b.knownCogs),
      cogsComplete:
          s.every((x) => x.cogsComplete) &&
          !wasteRecords.any((w) => inPeriod(w.at) && w.cost == null),
      opex: sum(e.where((x) => x.type == ExpenseType.businessExpense)),
      personal: sum(e.where((x) => x.type == ExpenseType.personalWithdrawal)),
      inventoryPurchases: sum(
        e.where((x) => x.type == ExpenseType.inventoryPurchase),
      ),
      saleCount: s.length,
      itemsSold: s.fold(
        0,
        (a, b) => a + b.items.fold<double>(0, (q, i) => q + i.qty).round(),
      ),
    );
  }

  PeriodSummary summaryForDay(DateTime d) =>
      summary((x) => dayKey(x) == dayKey(d));
  PeriodSummary summaryForMonth(DateTime d) =>
      summary((x) => monthKey(x) == monthKey(d));

  /// Stock valuation; null if any product with stock has unknown cost.
  double? get stockValue {
    var total = 0.0;
    for (final p in activeProducts) {
      if (p.qty <= 0) continue;
      if (p.avgCost == null) return null;
      total += p.qty * p.avgCost!;
    }
    return total;
  }

  double get stockValueKnown => activeProducts.fold(
    0,
    (s, p) => s + (p.avgCost == null ? 0 : p.qty * p.avgCost!),
  );

  /// Per-product performance within a period.
  List<ProductPerf> productPerformance(bool Function(DateTime) inPeriod) {
    final map = <String, ProductPerf>{};
    for (final s in sales.where((x) => inPeriod(x.date))) {
      for (final i in s.items) {
        final pp = map.putIfAbsent(
          i.productId,
          () => ProductPerf(i.productId, i.productName),
        );
        pp.qty += i.qty;
        pp.revenue += i.total;
        if (i.cogs == null) {
          pp.cogsComplete = false;
        } else {
          pp.cogs += i.cogs!;
        }
      }
    }
    final out = map.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
    return out;
  }

  /// Revenue for each of the last [days] days, oldest first.
  List<MapEntry<DateTime, double>> revenueTrend(int days) {
    final base = DateTime(now.year, now.month, now.day);
    return List.generate(days, (i) {
      final d = base.subtract(Duration(days: days - 1 - i));
      return MapEntry(d, summaryForDay(d).revenue);
    });
  }

  double qtySoldSince(String productId, DateTime since) => sales
      .where((s) => !s.date.isBefore(since))
      .expand((s) => s.items)
      .where((i) => i.productId == productId)
      .fold(0, (a, b) => a + b.qty);

  // ------------------------------------------------------------- insights
  /// Evidence-backed insights. Figures are computed deterministically here;
  /// in production Gemini only rewords this bounded context.
  List<Insight> get _rawInsights {
    final out = <Insight>[];
    final week = now.subtract(const Duration(days: 7));

    if (products.isEmpty) {
      out.add(
        const Insight(
          id: 'no_data',
          kind: InsightKind.onboarding,
          category: 'Data',
          title: 'Mulai dengan foto catatan stok',
          priority: InsightPriority.medium,
          evidence: ['Belum ada produk tercatat.'],
          action: 'Buka Scan → Stok awal, lalu foto catatan stokmu.',
          caveat: 'Wawasan akan muncul setelah ada data yang dikonfirmasi.',
        ),
      );
      return out;
    }

    for (final p in activeProducts.where((p) => p.isLowStock)) {
      final sold = qtySoldSince(p.id, week);
      final suggest = (p.minQty * 2 - p.qty).clamp(1, 9999).ceil();
      out.add(
        Insight(
          id: 'low_${p.id}',
          kind: InsightKind.lowStock,
          category: 'Stok menipis',
          title: '${p.name} hampir habis',
          priority: p.qty <= 0 ? InsightPriority.high : InsightPriority.medium,
          evidence: [
            'Sisa stok ${fmtQty(p.qty)} ${p.unit} (batas minimum ${fmtQty(p.minQty)}).',
            if (sold > 0)
              'Terjual ${fmtQty(sold)} ${p.unit} dalam 7 hari terakhir.',
          ],
          action: 'Restock ${p.name} sekitar $suggest ${p.unit}.',
          caveat: sold == 0
              ? 'Belum ada data penjualan 7 hari untuk memperkirakan kebutuhan.'
              : null,
          missionId: 'restock_${p.id}',
        ),
      );
    }

    final missing = activeProducts.where((p) => p.avgCost == null).toList();
    if (missing.isNotEmpty) {
      out.add(
        Insight(
          id: 'missing_cost',
          kind: InsightKind.missingCost,
          category: 'Harga modal',
          title: '${missing.length} produk belum punya harga modal',
          priority: InsightPriority.medium,
          evidence: [
            'Produk: ${missing.take(4).map((p) => p.name).join(', ')}${missing.length > 4 ? ', …' : ''}.',
            'Laba dari produk ini tidak bisa dihitung dengan pasti.',
          ],
          action:
              'Buka Stok, ketuk produk, lalu isi harga modal dari nota belanja.',
          caveat:
              'Kami tidak menganggap modal = Rp0; laba ditandai belum lengkap.',
          missionId: 'daily_costs',
        ),
      );
    }

    for (final p in activeProducts.where(
      (p) => p.marginPct != null && p.marginPct! < 10,
    )) {
      out.add(
        Insight(
          id: 'margin_${p.id}',
          kind: InsightKind.marginRisk,
          category: 'Risiko margin',
          title: 'Margin ${p.name} tipis',
          priority: p.marginPct! < 0
              ? InsightPriority.high
              : InsightPriority.medium,
          evidence: [
            'Modal rata-rata ${rp(p.avgCost!)}, harga jual ${rp(p.sellPrice)}.',
            'Margin ${p.marginPct!.toStringAsFixed(1)}%.',
          ],
          action: 'Tinjau harga jual atau cari pemasok lebih murah.',
          caveat: 'Pertimbangkan harga pasar sekitar sebelum menaikkan harga.',
        ),
      );
    }

    final t = summaryForDay(now);
    final y = summaryForDay(now.subtract(const Duration(days: 1)));
    if (t.hasSales && y.hasSales && y.revenue > 0) {
      final ch = (t.revenue - y.revenue) / y.revenue * 100;
      out.add(
        Insight(
          id: 'sales_change',
          kind: InsightKind.salesChange,
          category: 'Perubahan penjualan',
          title:
              'Omzet hari ini ${ch >= 0 ? 'naik' : 'turun'} ${ch.abs().toStringAsFixed(0)}%',
          priority: InsightPriority.low,
          evidence: ['Hari ini ${rp(t.revenue)} vs kemarin ${rp(y.revenue)}.'],
          action: ch >= 0
              ? 'Pastikan stok produk terlaris cukup untuk besok.'
              : 'Cek apakah ada produk yang kosong sehingga pembeli pergi.',
          caveat: 'Perbandingan 2 hari belum cukup untuk melihat tren.',
        ),
      );
    }

    final perf = productPerformance((d) => !d.isBefore(week));
    if (perf.isNotEmpty) {
      final total = perf.fold<double>(0, (s, p) => s + p.revenue);
      final top = perf.first;
      out.add(
        Insight(
          id: 'top_product',
          kind: InsightKind.topProduct,
          category: 'Produk terlaris',
          title: '${top.name} penyumbang omzet terbesar',
          priority: InsightPriority.low,
          evidence: [
            '${rp(top.revenue)} dari ${rp(total)} (${(top.revenue / total * 100).toStringAsFixed(0)}%) dalam 7 hari.',
            'Terjual ${fmtQty(top.qty)} unit.',
          ],
          action:
              'Letakkan ${top.name} di tempat yang mudah terlihat dan jaga stoknya.',
        ),
      );
    }

    final m = summaryForMonth(now);
    if (m.grossProfit != null && m.opex > 0 && m.opex > m.grossProfit!) {
      out.add(
        Insight(
          id: 'expense_anomaly',
          kind: InsightKind.expense,
          category: 'Biaya',
          title: 'Biaya usaha melebihi laba kotor bulan ini',
          priority: InsightPriority.high,
          evidence: [
            'Biaya usaha ${rp(m.opex)} vs laba kotor ${rp(m.grossProfit!)}.',
          ],
          action: 'Tinjau biaya terbesar di Laporan → Biaya.',
          caveat:
              'Bisa jadi karena penjualan bulan ini belum semuanya dicatat.',
        ),
      );
    }

    if (!sales.any((s) => dayKey(s.date) == today)) {
      out.add(
        Insight(
          id: 'record_$today',
          kind: InsightKind.recordHabit,
          category: 'Kebiasaan mencatat',
          title: 'Belum ada catatan penjualan hari ini',
          priority: InsightPriority.low,
          evidence: [
            'Hari tercatat sejauh ini: $verifiedRecordDays hari.',
            if (recordStreak > 0)
              'Streak saat ini $recordStreak hari — jangan sampai putus.',
          ],
          action: 'Foto catatan penjualan sebelum tutup warung.',
          caveat: verifiedRecordDays < 3
              ? 'Perlu minimal 3 hari data untuk mulai melihat pola.'
              : null,
        ),
      );
    }
    return out;
  }

  // ------------------------------------------------ personalization (§10.1)
  static const _priorityScore = {
    InsightPriority.high: 30,
    InsightPriority.medium: 20,
    InsightPriority.low: 10,
  };

  InsightFeedback? feedbackFor(String insightId) {
    for (final f in feedback.reversed) {
      if (f.insightId == insightId) return f;
    }
    return null;
  }

  /// Net feedback on a kind of insight (useful − not useful).
  int kindAffinity(InsightKind k) => feedback
      .where((f) => f.kind == k)
      .fold(0, (s, f) => s + (f.useful ? 1 : -1));

  /// Ranking score: priority + goal relevance + learned feedback.
  int insightScore(Insight i) {
    final g = profile?.goal;
    var score = _priorityScore[i.priority]!;
    if (g != null && goalKinds[g]!.contains(i.kind)) score += 25;
    score += 6 * kindAffinity(i.kind);
    if (feedbackFor(i.id)?.useful == true) score += 3;
    return score;
  }

  String? _why(Insight i) {
    final g = profile?.goal;
    final parts = <String>[];
    if (g != null && goalKinds[g]!.contains(i.kind)) {
      parts.add('Sesuai tujuanmu: ${ownerGoalLabels[g]}');
    }
    final a = kindAffinity(i.kind);
    if (a > 0) parts.add('kamu menandai saran sejenis berguna');
    if (a < 0) parts.add('diturunkan karena masukanmu');
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// Personalized insights: dismissed ones are hidden, the rest ranked.
  List<Insight> get insights {
    final list = _rawInsights
        .where((i) => feedbackFor(i.id)?.useful != false)
        .map((i) => i.withWhy(_why(i)))
        .toList();
    final idx = {for (var k = 0; k < list.length; k++) list[k].id: k};
    list.sort((a, b) {
      final c = insightScore(b).compareTo(insightScore(a));
      return c != 0 ? c : idx[a.id]!.compareTo(idx[b.id]!);
    });
    return list;
  }

  int get hiddenInsightCount =>
      _rawInsights.where((i) => feedbackFor(i.id)?.useful == false).length;

  Future<void> rateInsight(Insight i, bool useful) async {
    feedback.removeWhere((f) => f.insightId == i.id);
    feedback.add(
      InsightFeedback(insightId: i.id, kind: i.kind, useful: useful, at: now),
    );
    profile?.updatedAt = now;
    await _save();
  }

  Future<void> setGoal(OwnerGoal g) async {
    business?.priority = ownerGoalLabels[g]!;
    profile ??= OwnerAiProfile(updatedAt: now);
    profile!
      ..goal = g
      ..updatedAt = now;
    await _save();
  }

  Future<void> setStyle(ExplainStyle st) async {
    profile ??= OwnerAiProfile(updatedAt: now);
    profile!
      ..style = st
      ..updatedAt = now;
    await _save();
  }

  /// Remembers handwritten spellings the owner confirmed for a product.
  void _learnAliases(SourceDocument doc) {
    final prof = profile;
    if (prof == null) return;
    for (final r in doc.rows.where((r) => r.include && r.productId != null)) {
      final key = normalizeText(r.name);
      final p = productById(r.productId)!;
      if (key.isEmpty || key == normalizeText(p.name)) continue;
      prof.aliases[key] = p.id;
      if (!p.aliases.map(normalizeText).contains(key)) {
        p.aliases = [...p.aliases, r.name.trim()];
      }
    }
    prof.updatedAt = now;
  }

  Future<void> removeAlias(String alias) async {
    final pid = profile?.aliases.remove(alias);
    final p = productById(pid);
    if (p != null) {
      p.aliases = p.aliases.where((a) => normalizeText(a) != alias).toList();
    }
    await _save();
  }

  Future<void> clearFeedback() async {
    feedback = [];
    adviceFeedback.clear();
    advice = null;
    adviceContextSaved = null;
    await _save();
  }

  /// Owner-controlled reset of everything learned (goal/style stay explicit).
  Future<void> resetLearning() async {
    for (final alias in List.of(profile?.aliases.keys ?? <String>[])) {
      final p = productById(profile!.aliases[alias]);
      if (p != null) {
        p.aliases = p.aliases.where((a) => normalizeText(a) != alias).toList();
      }
    }
    profile?.aliases.clear();
    profile?.skippedMissions.clear();
    profile?.updatedAt = now;
    feedback = [];
    adviceFeedback.clear();
    advice = null;
    adviceContextSaved = null;
    await _save();
  }

  /// 1 onboarding context · 2 verified patterns · 3 feedback-adapted.
  int get personalizationStage {
    if (feedback.isNotEmpty ||
        adviceFeedback.isNotEmpty ||
        (profile?.aliases.isNotEmpty ?? false)) {
      return 3;
    }
    if (verifiedRecordDays >= 1) return 2;
    return 1;
  }

  // ------------------------------------------------------------- missions
  bool isMissionAccepted(String id) => acceptedMissions.any((m) => m.id == id);

  Future<void> acceptAiMission(String missionId) async {
    if (isMissionAccepted(missionId) || !missionId.startsWith('restock_')) {
      return;
    }
    final pid = missionId.substring('restock_'.length);
    acceptedMissions.add(AcceptedMission(missionId, 'restock', pid, today));
    await _save();
  }

  bool _skippedToday(String id) =>
      profile?.skippedMissions.contains('${id}_$today') ?? false;

  Future<void> skipMission(String id) async {
    profile ??= OwnerAiProfile(updatedAt: now);
    profile!.skippedMissions.add('${id}_$today');
    await _save();
  }

  /// Number of days the owner skipped this mission (drives selection).
  int skipCount(String id) =>
      profile?.skippedMissions.where((k) => k.startsWith('${id}_')).length ?? 0;

  static const _goalMissions = {
    OwnerGoal.stockAvailability: {'restock', 'daily_sales'},
    OwnerGoal.profitability: {'daily_costs', 'daily_expense'},
    OwnerGoal.recordCompleteness: {
      'daily_sales',
      'starter_first_sale',
      'daily_expense',
    },
  };

  bool isGoalMission(String id) {
    final g = profile?.goal;
    if (g == null) return false;
    final set = _goalMissions[g]!;
    return set.contains(id) ||
        (id.startsWith('restock_') && set.contains('restock'));
  }

  String _claimKey(Mission m) =>
      m.id.startsWith('daily_') ? 'mission_${m.id}_$today' : 'mission_${m.id}';

  /// Missions selected for this owner: skipped-today daily missions are
  /// hidden, goal-relevant ones first, often-skipped ones last.
  List<Mission> get missions {
    final all = _allMissions
        .where(
          (m) =>
              !(m.id.startsWith('daily_') && _skippedToday(m.id) && !m.claimed),
        )
        .toList();
    final idx = {for (var k = 0; k < all.length; k++) all[k].id: k};
    int rank(Mission m) => (isGoalMission(m.id) ? 0 : 10) + skipCount(m.id);
    all.sort((a, b) {
      final c = rank(a).compareTo(rank(b));
      return c != 0 ? c : idx[a.id]!.compareTo(idx[b.id]!);
    });
    return all;
  }

  List<Mission> get _allMissions {
    if (business?.type != null && serviceFirst && !hasGoods) {
      return [...operationalMissions, if (producesGoods) ...productionMissions];
    }
    final out = <Mission>[];
    bool claimed(String id, {bool daily = false}) =>
        hasAward(daily ? 'mission_${id}_$today' : 'mission_$id');

    // Starter missions
    out.add(
      Mission(
        id: 'starter_stock',
        title: 'Catat 3 produk stok awal',
        description: 'Foto catatan stok atau tambah manual.',
        xp: XpRules.dailyMission,
        progress: (products.length / 3).clamp(0, 1),
        claimed: claimed('starter_stock'),
      ),
    );
    out.add(
      Mission(
        id: 'starter_first_sale',
        title: 'Konfirmasi penjualan pertama',
        description: 'Catat manual atau foto, cek lalu konfirmasi.',
        xp: XpRules.dailyMission,
        progress: sales.isNotEmpty ? 1 : 0,
        claimed: claimed('starter_first_sale'),
      ),
    );

    // Daily missions
    out.add(
      Mission(
        id: 'daily_sales',
        title: 'Catat penjualan hari ini',
        description: 'Satu catatan penjualan terkonfirmasi untuk hari ini.',
        xp: XpRules.dailyMission,
        progress: sales.any((s) => dayKey(s.date) == today) ? 1 : 0,
        claimed: claimed('daily_sales', daily: true),
      ),
    );
    final withCost = products.where((p) => p.avgCost != null).length;
    out.add(
      Mission(
        id: 'daily_costs',
        title: 'Lengkapi semua harga modal',
        description: 'Agar laba bisa dihitung akurat.',
        xp: XpRules.dailyMission,
        progress: products.isEmpty ? 0 : withCost / products.length,
        claimed: claimed('daily_costs', daily: true),
      ),
    );
    out.add(
      Mission(
        id: 'daily_expense',
        title: 'Catat 1 biaya usaha hari ini',
        description: 'Listrik, transport, plastik, dll.',
        xp: XpRules.dailyMission,
        progress:
            expenses.any(
              (e) =>
                  dayKey(e.date) == today &&
                  e.type == ExpenseType.businessExpense,
            )
            ? 1
            : 0,
        claimed: claimed('daily_expense', daily: true),
      ),
    );

    // AI-proposed missions (verified against confirmed stock state)
    for (final a in acceptedMissions) {
      final p = productById(a.productId);
      if (p == null) continue;
      final target = p.minQty + 1;
      out.add(
        Mission(
          id: a.id,
          title: 'Restock ${p.name}',
          description:
              'Naikkan stok di atas batas minimum (${fmtQty(p.minQty)} ${p.unit}).',
          xp: XpRules.aiMission,
          fromAi: true,
          progress: (p.qty / target).clamp(0, 1),
          claimed: claimed(a.id),
        ),
      );
    }
    if (producesGoods) out.addAll(productionMissions);
    if (hasServices) {
      final ids = out.map((m) => m.id).toSet();
      out.addAll(operationalMissions.where((m) => !ids.contains(m.id)));
    }
    return out;
  }

  /// Verifies mission against confirmed state, then awards XP once.
  Future<int> claimMission(String id) async {
    final m = _allMissions.firstWhere((m) => m.id == id);
    if (!m.verified || m.claimed) return 0;
    final gained = _award(_claimKey(m), 'Misi: ${m.title}', m.xp);
    await _save();
    return gained;
  }

  int get claimableCount =>
      missions.where((m) => m.verified && !m.claimed).length;

  /// Consecutive days (ending today or yesterday) with confirmed sales.
  int get recordStreak {
    final days = sales.map((s) => dayKey(s.date)).toSet();
    var d = DateTime(now.year, now.month, now.day);
    if (!days.contains(dayKey(d))) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (days.contains(dayKey(d))) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  /// North Star: verified business record days.
  int get verifiedRecordDays => sales.map((s) => dayKey(s.date)).toSet().length;

  // ---------------------------------------------------------- demo scenarios
  /// Replaces local data with a labeled demo warung that already has two days
  /// of confirmed history, so personalization can be shown without claiming
  /// weeks of live learning (PRD §10.1). Postings go through the normal
  /// confirm path, so all ledger rules still apply.
  Future<void> loadDemoScenario(OwnerGoal goal) async {
    if (googleEnabled) {
      throw StateError('Skenario demo tidak tersedia untuk akun Google.');
    }
    final keepUser = userName ?? 'Pemilik Warung';
    final keepEmail = userEmail ?? 'demo@warungpilot.app';
    await resetAll();
    userName = keepUser;
    userEmail = keepEmail;
    final profit = goal == OwnerGoal.profitability;
    final realClock = clock;
    final today0 = DateTime(now.year, now.month, now.day, 12);
    DateTime daysAgo(int n) => today0.subtract(Duration(days: n));
    try {
      clock = () => daysAgo(3);
      await createBusiness(
        name: profit ? 'Toko Pak Budi' : 'Warung Bu Sari',
        owner: profit ? 'Pak Budi' : 'Bu Sari',
        city: profit ? 'Yogyakarta' : 'Bandung',
        goal: goal,
        style: profit ? ExplainStyle.detailed : ExplainStyle.concise,
      );
      Product add(
        String name,
        double qty,
        double? cost,
        double sell,
        double min,
      ) {
        final p = Product(
          id: newId('prd'),
          name: name,
          sellPrice: sell,
          avgCost: cost,
          qty: qty,
          minQty: min,
          category: 'Sembako & minuman',
        );
        products.add(p);
        movements.add(
          StockMovement(
            id: newId('mv'),
            productId: p.id,
            type: MovementType.opening,
            qtyDelta: qty,
            unitCost: cost,
            sourceId: 'demo_seed',
            date: daysAgo(3),
            createdAt: daysAgo(3),
          ),
        );
        return p;
      }

      final indomie = add('Indomie Goreng', 30, 2600, 3500, 5);
      final aqua = add('Aqua 600ml', 24, 3000, 4000, 8);
      final teh = add('Teh Pucuk', 20, 3500, 5000, 5);
      final kopi = add('Kopi Kapal Api Sachet', 40, 1400, 1500, 10);
      add('Gula Pasir 1kg', 8, null, 16000, 3);
      _award('opening_stock', 'Stok awal tercatat', XpRules.openingStock);

      Future<void> sale(int ago, Map<Product, double> items) async {
        clock = () => daysAgo(ago);
        final doc = await createDocument(DocKind.dailySales);
        doc
          ..status = DocStatus.draft
          ..date = daysAgo(ago)
          ..rows = [
            for (final e in items.entries)
              DraftRow(
                rawText: '(contoh demo)',
                name: e.key.name,
                productId: e.key.id,
                qty: e.value,
                unitPrice: e.key.sellPrice,
              ),
          ];
        await confirmDocument(doc.id);
      }

      await sale(2, {indomie: 6, aqua: 8, kopi: 10});
      await sale(1, {indomie: 8, aqua: 9, teh: 3, kopi: 12});
      clock = () => daysAgo(1);
      await addExpenseManual(
        description: 'Token listrik PLN',
        category: 'Listrik & air',
        amount: 50000,
        type: ExpenseType.businessExpense,
      );

      if (profit) {
        // Example history for scenario B: an alias the owner confirmed earlier
        // and one piece of feedback. Labeled as demo data in the profile page.
        profile!.aliases['teh pcuk'] = teh.id;
        teh.aliases = [...teh.aliases, 'teh pcuk'];
        feedback.add(
          InsightFeedback(
            insightId: 'top_product',
            kind: InsightKind.topProduct,
            useful: false,
            at: daysAgo(1),
          ),
        );
      }
    } finally {
      clock = realClock;
    }
    await _save();
  }
}

class ProductPerf {
  final String productId;
  final String name;
  double qty = 0;
  double revenue = 0;
  double cogs = 0;
  bool cogsComplete = true;
  ProductPerf(this.productId, this.name);
  double? get profit => cogsComplete ? revenue - cogs : null;
}
