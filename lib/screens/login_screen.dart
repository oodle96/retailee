import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/app_ui.dart';
import '../widgets/brand.dart';
import '../widgets/retail_art.dart';
import '../widgets/common.dart';
import 'language_setup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;

  Future<void> _signIn() async {
    setState(() => _busy = true);
    try {
      await StoreScope.read(context).signIn();
    } catch (e) {
      if (mounted) {
        showMessage(context, 'Belum berhasil masuk. $e', error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final googleEnabled = StoreScope.of(context).googleEnabled;
    return AppUi(
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [RetaileeWordmark(), LanguageButton()],
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primarySoft, AppColors.infoSoft],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: RetailArt(scene: RetailScene.notebook, width: 200),
                    ),
                    const LocalText(
                      'Catatan tetap di buku.\nUsaha makin terbaca.',
                      style: TextStyle(
                        fontSize: 26,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const LocalText(
                      'Foto · Periksa · Jurnal · Saran',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              AppSection(
                children: [
                  _feature(
                    Icons.photo_camera_outlined,
                    'Foto catatan tulisan tangan',
                  ),
                  _feature(
                    Icons.fact_check_outlined,
                    'Periksa & konfirmasi, kamu yang memutuskan',
                  ),
                  _feature(
                    Icons.insights_outlined,
                    'Stok, omzet & laba otomatis',
                  ),
                  _feature(
                    Icons.emoji_events_outlined,
                    'Misi & XP untuk usaha yang lebih rapi',
                  ),
                ],
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: FilledButton.icon(
              onPressed: _busy ? null : _signIn,
              icon: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      googleEnabled
                          ? Icons.login_rounded
                          : Icons.play_circle_outline,
                    ),
              label: LocalText(
                _busy
                    ? 'Memuat...'
                    : googleEnabled
                    ? 'Masuk dengan Google'
                    : 'Coba demo lokal',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _feature(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: LocalText(
            text,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}
