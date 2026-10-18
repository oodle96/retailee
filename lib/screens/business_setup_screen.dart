import 'package:flutter/material.dart';
import '../business_types.dart';
import '../models.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/business_profile_confirmation.dart';
import '../widgets/common.dart';
import '../widgets/brand.dart';
import '../widgets/business_icons.dart' show businessGoalIcon;
import 'language_setup_screen.dart';

class BusinessSetupScreen extends StatefulWidget {
  final bool editing;
  const BusinessSetupScreen({super.key, this.editing = false});
  @override
  State<BusinessSetupScreen> createState() => _BusinessSetupState();
}

class _BusinessSetupState extends State<BusinessSetupScreen> {
  final _name = TextEditingController(),
      _owner = TextEditingController(),
      _city = TextEditingController();
  final _subtype = TextEditingController(),
      _unit = TextEditingController(),
      _context = TextEditingController();
  final _scroll = ScrollController();
  BusinessType? _type;
  String? _choice;
  final Set<String> _activities = {};
  String? _goal;
  ExplainStyle _style = ExplainStyle.concise;
  bool _initialized = false, _busy = false;
  int _step = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final store = StoreScope.read(context),
        b = StoreScope.read(context).business;
    _name.text = b?.name ?? '';
    _owner.text = b?.ownerName ?? store.userName ?? '';
    _city.text = b?.city ?? '';
    _subtype.text = b?.subtype ?? '';
    _context.text = b?.purpose ?? '';
    _type = b == null ? null : store.businessType;
    if (b != null) {
      _activities.addAll(store.businessActivities);
      _choice = _activities.length > 1 ? 'mixed' : _activities.single;
    }
    _unit.text = b?.pricingUnit ?? 'unit';
    _goal = b?.priority.isNotEmpty == true ? b!.priority : null;
    _style = store.profile?.style ?? ExplainStyle.concise;
  }

  @override
  void dispose() {
    for (final c in [_name, _owner, _city, _subtype, _unit, _context]) {
      c.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_step == 0 &&
        (_choice == null || (_choice == 'mixed' && _activities.length < 2))) {
      showMessage(
        context,
        _choice == 'mixed'
            ? 'Pilih minimal dua kegiatan usaha.'
            : 'Pilih cara kerja usahamu.',
        error: true,
      );
      return;
    }
    if (_step == 1 &&
        (_name.text.trim().isEmpty || _unit.text.trim().isEmpty)) {
      showMessage(context, 'Isi nama usaha dan satuan harga.', error: true);
      return;
    }
    if (_step == 1 && _context.text.trim().isEmpty) {
      showMessage(
        context,
        'Ceritakan apa yang dibayar pelanggan dan bagaimana kamu mengerjakannya.',
        error: true,
      );
      return;
    }
    if (_step < 2) {
      setState(() => _step++);
      _scroll.jumpTo(0);
      return;
    }
    if (_goal == null) {
      showMessage(context, 'Pilih tujuan utama.', error: true);
      return;
    }
    setState(() => _busy = true);
    final store = StoreScope.read(context);
    try {
      final understanding = await _understand(store);
      if (understanding == null || !mounted) return;
      if (store.business == null) {
        await store.createBusiness(
          name: _name.text.trim(),
          owner: _owner.text.trim(),
          city: _city.text.trim(),
          type: _type,
          subtype: _subtype.text.trim(),
          purpose: _context.text.trim(),
          pricingUnit: _unit.text.trim(),
          priority: _goal!,
          style: _style,
          goal: _goal == 'Stok selalu tersedia'
              ? OwnerGoal.stockAvailability
              : _goal == 'Untung lebih besar'
              ? OwnerGoal.profitability
              : OwnerGoal.recordCompleteness,
        );
      } else {
        await store.configureBusiness(
          type: _type!,
          subtype: _subtype.text,
          purpose: _context.text,
          pricingUnit: _unit.text,
          priority: _goal!,
        );
        store.business!
          ..name = _name.text.trim()
          ..ownerName = _owner.text.trim()
          ..city = _city.text.trim();
        await store.setStyle(_style);
      }
      await store.saveUnderstanding(understanding);
      if (mounted && widget.editing) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        showMessage(context, 'Belum dapat disimpan. $e', error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Map<String, dynamic>?> _understand(AppStore store) async {
    final answers = <Map<String, String>>[];
    while (mounted) {
      final payload = {
        'activities': _activities.toList(),
        'type': _type!.name,
        'subtype': _subtype.text.trim(),
        'purpose': _context.text.trim(),
        'pricingUnit': _unit.text.trim(),
        'goal': _goal!,
        'style': _style.name,
        'language': store.languageCode,
      };
      if (store.advisor == null && _activities.isEmpty) {
        if (!mounted) return null;
        showMessage(
          context,
          'Gemini tidak tersedia di demo lokal. Pilih kegiatan usaha untuk melanjutkan.',
          error: true,
        );
        setState(() => _step = 0);
        return null;
      }
      final result = store.advisor == null
          ? <String, dynamic>{
              'activities': _activities.toList(),
              'summary': '${_subtype.text}\n${_context.text}',
              'type': _type!.name,
              'mode': _activities.contains('services')
                  ? _activities.length > 1
                        ? 'mixed'
                        : 'services'
                  : 'goods',
              'pricingUnit': _unit.text.trim(),
              'usesMaterials': _activities.contains('production'),
              'questions': <String>[],
              'model': 'manual',
            }
          : await store.advisor!.understand(payload, answers);
      if (!mounted) return null;
      final questions = List<String>.from(result['questions']);
      if (questions.isNotEmpty) {
        if (answers.length + questions.length > 6) {
          showMessage(
            context,
            'Perjelas deskripsi usaha lalu coba lagi.',
            error: true,
          );
          return null;
        }
        for (final question in questions) {
          final controller = TextEditingController();
          final answer = await showDialog<String>(
            context: context,
            builder: (d) => AlertDialog(
              title: const LocalText('Bantu Gemini memahami usahamu'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(question),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      maxLength: 600,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: appTr(d, 'Jawabanmu'),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(d),
                  child: const LocalText('Kembali'),
                ),
                FilledButton(
                  onPressed: () {
                    if (controller.text.trim().isNotEmpty) {
                      Navigator.pop(d, controller.text.trim());
                    }
                  },
                  child: const LocalText('Lanjut'),
                ),
              ],
            ),
          );
          controller.dispose();
          if (answer == null || !mounted) return null;
          answers.add({'question': question, 'answer': answer});
        }
        continue;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (d) => BusinessProfileConfirmation(
          title: store.advisor == null
              ? 'Konfirmasi profil manual'
              : 'Apakah ini sesuai usahamu?',
          summary: result['summary'] as String,
          activities: List<String>.from(result['activities']),
          manual: store.advisor == null,
        ),
      );
      if (confirmed != true) {
        if (mounted) setState(() => _step = 1);
        return null;
      }
      _type = parseBusinessType(result['type']) ?? _type;
      _unit.text = result['pricingUnit'] as String;
      return {
        ...result,
        'answers': answers,
        'confirmedAt': DateTime.now().toIso8601String(),
      };
    }
    return null;
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool required = false,
    int lines = 1,
    int max = 160,
    String? hint,
    IconData icon = Icons.edit_outlined,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primaryDark, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: LocalText(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        if (required) ...[
          const SizedBox(height: 4),
          const LocalText(
            'Wajib',
            style: TextStyle(fontSize: 12, color: Color(0xFF65687B)),
          ),
        ],
        const SizedBox(height: 9),
        Semantics(
          label: appTr(context, label),
          child: TextField(
            key: PageStorageKey('profile-field-$label'),
            controller: c,
            enabled: !_busy,
            maxLength: max,
            maxLines: lines,
            style: const TextStyle(fontSize: 16, color: AppColors.ink),
            scrollPadding: const EdgeInsets.only(bottom: 120),
            decoration: InputDecoration(
              hintText: hint == null ? null : appTr(context, hint),
              hintStyle: const TextStyle(
                color: Color(0xFF777589),
                fontSize: 14,
              ),
              counterText: '',
              filled: true,
              fillColor: const Color(0xFFFAFAFD),
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFFE1DFEC)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFFE1DFEC)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: AppColors.primaryDark,
                  width: 2,
                ),
              ),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
        ),
      ],
    ),
  );

  Widget _section(String title, IconData icon, List<Widget> children) =>
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE9EAF2)),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Material(
          color: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0EDFC),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(icon, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LocalText(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              ...children,
            ],
          ),
        ),
      );

  void _chooseActivity(String choice) {
    if (_busy) return;
    setState(() {
      _choice = choice;
      _activities.clear();
      if (choice == 'mixed') {
        _activities.addAll(['resale', 'services']);
      } else {
        _activities.add(choice);
      }
      _type = switch (choice) {
        'resale' => BusinessType.retail,
        'services' => BusinessType.services,
        _ => BusinessType.other,
      };
      _unit.text = 'unit';
      _goal = null;
    });
  }

  Widget _businessChoice(
    String choice,
    String title,
    String description,
    IconData icon,
  ) {
    final selected = _choice == choice;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        key: ValueKey('business-choice-$choice'),
        checked: selected,
        inMutuallyExclusiveGroup: true,
        child: Material(
          color: selected ? const Color(0xFFF0EDFC) : Colors.white,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: selected ? AppColors.primary : const Color(0xFFE9EAF2),
              width: 2,
            ),
          ),
          child: InkWell(
            onTap: _busy ? null : () => _chooseActivity(choice),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0EDFC),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(icon, size: 23, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: LocalText(
                          title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 23,
                        color: selected
                            ? AppColors.primary
                            : const Color(0xFF777589),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LocalText(
                    description,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: Color(0xFF65687B),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileHeader(bool previousRecords) => Container(
    margin: const EdgeInsets.only(bottom: 20),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFEEEAFE), Color(0xFFE0F2FF)],
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFE0DCF3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const RetaileeMark(size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: LocalText(
                '${_step + 1} / 3',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
            InfoButton(
              title: 'Tentang profil usaha',
              message: [
                'Foto catatan, simpan ke jurnal, dapatkan saran sesuai usahamu.',
                'Gunakan satuan yang biasa dipakai pelangganmu.',
                'Saran memakai tujuan, catatan terkonfirmasi dan masukanmu.',
              ][_step],
            ),
          ],
        ),
        const SizedBox(height: 14),
        Semantics(
          header: true,
          child: LocalText(
            [
              'Bagaimana usahamu bekerja?',
              'Kenalan dengan usahamu',
              'Apa yang ingin kamu rapikan?',
            ][_step],
            style: const TextStyle(
              fontSize: 23,
              height: 1.25,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
        ),
        const SizedBox(height: 8),
        LocalText(
          [
            'Pilih kegiatan yang kamu jalankan.',
            'Isi informasi yang dikenal pelangganmu.',
            'Pilih satu tujuan dan gaya penjelasan.',
          ][_step],
          style: const TextStyle(
            fontSize: 14,
            height: 1.45,
            color: Color(0xFF65687B),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < 3; i++)
              Expanded(
                child: Semantics(
                  selected: _step == i,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: !_busy && i < _step
                        ? () {
                            setState(() => _step = i);
                            _scroll.jumpTo(0);
                          }
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: i <= _step
                                  ? AppColors.primary
                                  : const Color(0xFFDCD8EE),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: i < _step
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  )
                                : Text(
                                    '${i + 1}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1,
                                      color: i == _step
                                          ? Colors.white
                                          : AppColors.primaryDark,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 6),
                          LocalText(
                            ['Kegiatan', 'Profil', 'Tujuan'][i],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _step == i
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (previousRecords && _step == 0) ...[
          const SizedBox(height: 14),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                color: AppColors.positive,
                size: 18,
              ),
              SizedBox(width: 8),
              Expanded(
                child: LocalText(
                  'Data usaha yang sudah ada tetap tersimpan.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Color(0xFF65687B),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final template = _type == null ? null : businessTemplates[_type]!;
    final goals = <String>{
      'Untung lebih besar',
      'Catatan rapi & lengkap',
      if (_activities.contains('resale')) 'Stok selalu tersedia',
      if (_activities.contains('services')) ...[
        'Pesanan selesai tepat waktu',
        'Pembayaran cepat lunas',
      ],
      ?_goal,
    };
    final previousRecords = StoreScope.of(context).business != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FC),
        foregroundColor: AppColors.ink,
        title: const LocalText(
          'Profil usaha',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        actions: const [LanguageButton(), SizedBox(width: 12)],
      ),
      body: SafeArea(
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          children: [
            _profileHeader(previousRecords),
            if (_step == 0)
              RadioGroup<String>(
                groupValue: _choice,
                onChanged: (v) {
                  if (v != null) _chooseActivity(v);
                },
                child: Column(
                  children: [
                    for (final activity in businessActivityLabels.keys)
                      _businessChoice(
                        activity,
                        businessActivityLabels[activity]!,
                        businessActivityDescriptions[activity]!,
                        switch (activity) {
                          'resale' => Icons.storefront_outlined,
                          'services' => Icons.handyman_outlined,
                          _ => Icons.factory_outlined,
                        },
                      ),
                    _businessChoice(
                      'mixed',
                      'Barang & jasa',
                      'Jual barang sekaligus menyediakan layanan.',
                      Icons.layers_outlined,
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      icon: const Icon(Icons.help_outline),
                      label: const LocalText('Belum yakin? Ceritakan usahamu'),
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _choice = 'unsure';
                              _activities.clear();
                              _type = BusinessType.other;
                              _goal = null;
                              _step = 1;
                              _scroll.jumpTo(0);
                            }),
                    ),
                  ],
                ),
              ),
            if (_step == 1) ...[
              _section('Tentang usahamu', Icons.storefront_outlined, [
                _field(
                  _name,
                  'Nama usaha',
                  required: true,
                  hint: 'Nama yang dikenal pelanggan',
                  icon: Icons.storefront_outlined,
                ),
                ExpansionTile(
                  key: const PageStorageKey('profile-owner-location'),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(top: 16),
                  shape: const Border(),
                  collapsedShape: const Border(),
                  title: const LocalText(
                    'Pemilik & lokasi (opsional)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  children: [
                    _field(_owner, 'Nama pemilik', icon: Icons.person_outline),
                    _field(
                      _city,
                      'Kota',
                      hint: 'Kota tempat usahamu',
                      icon: Icons.location_on_outlined,
                    ),
                  ],
                ),
              ]),
              _section('Cara kerja usaha', Icons.tune_rounded, [
                _field(
                  _subtype,
                  'Jenis usaha lebih spesifik',
                  hint:
                      'Misalnya ${_type == BusinessType.laundry ? 'laundry kiloan' : template!.examples.split(',').first}',
                  icon: Icons.category_outlined,
                  max: 160,
                ),
                if (_activities.contains('services') || _choice == 'unsure')
                  _field(
                    _unit,
                    'Satuan layanan utama',
                    required: true,
                    hint: 'Misalnya ${template!.unit}',
                    icon: Icons.sell_outlined,
                    max: 32,
                  ),
                if (_activities.contains('resale'))
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: LocalText(
                      'Setiap produk punya satuan sendiri, misalnya pcs, pack atau botol. Atur saat menambah produk.',
                    ),
                  ),
                _field(
                  _context,
                  'Apa yang dibayar pelanggan?',
                  required: true,
                  hint:
                      'Ceritakan barang atau jasa, bahan yang dipakai, dan cara kerjanya.',
                  icon: Icons.notes_rounded,
                  lines: 3,
                  max: 600,
                ),
              ]),
            ],
            if (_step == 2) ...[
              _section('Fokus utama', Icons.flag_outlined, [
                RadioGroup<String>(
                  groupValue: _goal,
                  onChanged: (v) => setState(() => _goal = v),
                  child: Column(
                    children: [
                      for (final goal in goals)
                        RadioListTile<String>(
                          value: goal,
                          contentPadding: EdgeInsets.zero,
                          title: LocalText(
                            goal,
                            style: const TextStyle(fontSize: 15, height: 1.4),
                          ),
                          secondary: Icon(
                            businessGoalIcon(goal),
                            color: AppColors.primaryDark,
                            size: 24,
                          ),
                        ),
                    ],
                  ),
                ),
              ]),
              _section('Arahan Gemini', Icons.auto_awesome_outlined, [
                const SizedBox(height: 14),
                const LocalText(
                  'Gaya penjelasan',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final style in ExplainStyle.values)
                      ChoiceChip(
                        label: LocalText(
                          style == ExplainStyle.concise ? 'Singkat' : 'Detail',
                        ),
                        selected: _style == style,
                        showCheckmark: false,
                        selectedColor: AppColors.primary,
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _style == style
                              ? Colors.white
                              : AppColors.primaryDark,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        onSelected: _busy
                            ? null
                            : (_) => setState(() => _style = style),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const LocalText(
                  'Gemini memberi saran, bukan mengubah pembukuan. Informasi bisa diperbarui melalui Profil usaha.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: Color(0xFF65687B),
                  ),
                ),
                const SizedBox(height: 20),
              ]),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Row(
            children: [
              if (_step > 0) ...[
                IconButton.filledTonal(
                  tooltip: appTr(context, 'Kembali'),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(56, 56),
                    backgroundColor: const Color(0xFFEEEAFE),
                    foregroundColor: AppColors.primaryDark,
                  ),
                  onPressed: _busy
                      ? null
                      : () {
                          setState(() => _step--);
                          _scroll.jumpTo(0);
                        },
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF352676),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 56),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: _busy ? null : _next,
                  icon: Icon(
                    _step == 2
                        ? Icons.check_rounded
                        : Icons.arrow_forward_rounded,
                  ),
                  label: LocalText(
                    _busy
                        ? 'Memahami usaha...'
                        : _step == 2
                        ? 'Simpan profil usaha'
                        : 'Lanjut',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
