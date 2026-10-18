import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/brand.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();
  final _name = TextEditingController(text: 'Warung Bu Sari');
  final _owner = TextEditingController(text: 'Bu Sari');
  final _city = TextEditingController(text: 'Bandung');
  bool _busy = false;
  int _step = 0;
  OwnerGoal? _goal;
  ExplainStyle _style = ExplainStyle.concise;

  @override
  void dispose() {
    _name.dispose();
    _owner.dispose();
    _city.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_goal == null) {
      showMessage(context, 'Pilih satu tujuan usaha dulu.', error: true);
      return;
    }
    setState(() => _busy = true);
    await StoreScope.read(context).createBusiness(
      name: _name.text.trim(),
      owner: _owner.text.trim(),
      city: _city.text.trim(),
      goal: _goal!,
      style: _style,
    );
  }

  static const _goalIcons = {
    OwnerGoal.stockAvailability: Icons.inventory_2_rounded,
    OwnerGoal.profitability: Icons.trending_up_rounded,
    OwnerGoal.recordCompleteness: Icons.fact_check_rounded,
  };

  Widget _goalCard(OwnerGoal g) {
    final sel = _goal == g;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: sel ? AppColors.primarySoft : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _goal = g),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: sel ? AppColors.primary : AppColors.line,
                width: sel ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _goalIcons[g],
                  color: sel ? AppColors.primary : AppColors.muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LocalText(
                        ownerGoalLabels[g]!,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      LocalText(
                        ownerGoalDescriptions[g]!,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  sel ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: sel ? AppColors.primary : AppColors.line,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 12),
              const Row(
                children: [
                  RetaileeMark(size: 52),
                  SizedBox(width: 12),
                  RetaileeWordmark(),
                ],
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Pill.ok(
                  'Profil usaha · ${_step + 1} dari 2',
                  icon: Icons.storefront,
                ),
              ),
              const SizedBox(height: 16),
              LocalText(
                _step == 0
                    ? 'Kenalan dengan warungmu'
                    : 'Apa yang ingin kamu perbaiki?',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.5,
                ),
              ),
              const SizedBox(height: 8),
              LocalText(
                _step == 0
                    ? 'Data contoh sudah terisi untuk demo. Sesuaikan dengan warungmu.'
                    : 'Pilih satu prioritas. Tujuan dan gaya penjelasan bisa diubah nanti.',
                style: TextStyle(color: AppColors.muted, fontSize: 16),
              ),
              const SizedBox(height: 28),
              Visibility(
                visible: _step == 0,
                maintainState: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _label('Nama warung'),
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.storefront_outlined),
                      ),
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? 'Nama warung wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    _label('Nama pemilik'),
                    TextFormField(
                      controller: _owner,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _label('Kota'),
                    TextFormField(
                      controller: _city,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.place_outlined),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              Visibility(
                visible: _step == 1,
                maintainState: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const InfoHeading(
                      title: 'Tujuan utamamu saat ini',
                      message:
                          'Saran AI akan diprioritaskan sesuai tujuan ini. Bisa diubah kapan saja.',
                    ),
                    for (final g in OwnerGoal.values) _goalCard(g),
                    const SizedBox(height: 12),
                    _label('Gaya penjelasan'),
                    SegmentedButton<ExplainStyle>(
                      segments: const [
                        ButtonSegment(
                          value: ExplainStyle.concise,
                          label: LocalText('Singkat'),
                          icon: Icon(Icons.short_text),
                        ),
                        ButtonSegment(
                          value: ExplainStyle.detailed,
                          label: LocalText('Detail'),
                          icon: Icon(Icons.notes),
                        ),
                      ],
                      selected: {_style},
                      onSelectionChanged: (v) =>
                          setState(() => _style = v.first),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.accentSoft,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.emoji_events, color: AppColors.warn),
                          SizedBox(width: 10),
                          Expanded(
                            child: LocalText(
                              'Daftarkan warung dan dapatkan +100 XP pertamamu!',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF6B4A00),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () {
                        if (_step == 0) {
                          if (_form.currentState!.validate()) {
                            FocusScope.of(context).unfocus();
                            setState(() => _step = 1);
                            _scroll.jumpTo(0);
                          }
                        } else {
                          _submit();
                        }
                      },
                child: LocalText(
                  _busy
                      ? 'Menyimpan…'
                      : _step == 0
                      ? 'Lanjut: pilih tujuan'
                      : 'Simpan & mulai catat stok',
                ),
              ),
              if (_step == 1)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () {
                          setState(() => _step = 0);
                          _scroll.jumpTo(0);
                        },
                  child: const LocalText('Kembali ke profil usaha'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 2),
    child: LocalText(t, style: const TextStyle(fontWeight: FontWeight.w700)),
  );
}
