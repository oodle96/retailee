import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/app_ui.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';

class LanguageSetupScreen extends StatefulWidget {
  final bool editing;
  final VoidCallback? onCompleted;
  const LanguageSetupScreen({
    super.key,
    this.editing = false,
    this.onCompleted,
  });
  @override
  State<LanguageSetupScreen> createState() => _LanguageSetupState();
}

class _LanguageSetupState extends State<LanguageSetupScreen> {
  String? _selected;
  bool _busy = false;
  String? _error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _selected ??= StoreScope.read(context).languageCode;
  }

  Future<void> _continue() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await StoreScope.read(context).setLanguage(_selected!);
      if (!mounted) return;
      if (widget.onCompleted != null) {
        widget.onCompleted!();
      } else if (widget.editing && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = _selected == 'en'
              ? 'Could not save your language. Please try again.'
              : 'Bahasa belum tersimpan. Coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppUi(
    child: Scaffold(
      backgroundColor: appCanvas,
      appBar: widget.editing ? AppBar(title: const LocalText('Bahasa')) : null,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const RetaileeWordmark(),
            const SizedBox(height: 24),
            const AppHero(
              title: 'Pilih bahasa / Choose your language',
              message:
                  'Bahasa bisa diubah kapan saja. / You can change it anytime.',
              icon: Icons.language_rounded,
            ),
            RadioGroup<String>(
              groupValue: _selected,
              onChanged: _busy
                  ? (_) {}
                  : (value) => setState(() => _selected = value),
              child: Column(
                children: [
                  _choice(
                    'id',
                    'Bahasa Indonesia',
                    'Gunakan Retailee dalam Bahasa Indonesia',
                    'ID',
                  ),
                  _choice('en', 'English', 'Use Retailee in English', 'EN'),
                ],
              ),
            ),
            if (_error != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
            ),
            onPressed: _busy ? null : _continue,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(
              _busy
                  ? (_selected == 'en' ? 'Saving...' : 'Menyimpan...')
                  : (_selected == 'en' ? 'Continue' : 'Lanjut'),
            ),
          ),
        ),
      ),
    ),
  );
  Widget _choice(
    String value,
    String title,
    String description,
    String short,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Material(
      color: _selected == value ? AppColors.primarySoft : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: _selected == value ? AppColors.primaryDark : AppColors.line,
          width: 2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: RadioListTile<String>(
        value: value,
        enabled: !_busy,
        controlAffinity: ListTileControlAffinity.trailing,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        secondary: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFD9D2FB),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            short,
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: AppColors.ink,
            ),
          ),
        ),
      ),
    ),
  );
}

class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});
  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
    tooltip: appTr(context, 'Bahasa'),
    icon: const Icon(Icons.language_rounded),
    onPressed: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LanguageSetupScreen(editing: true),
      ),
    ),
  );
}
