import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/language_setup_screen.dart';

import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/business_setup_screen.dart';
import 'services/cloud_extractor.dart';
import 'services/google_services.dart';
import 'services/personalization_client.dart';
import 'services/store.dart';
import 'theme.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  // Real Gemini extraction is on when built with
  //   --dart-define=AI_ENDPOINT=https://<service>.run.app --dart-define=AI_APP_KEY=<key>
  // Without them the app uses the offline demo extractor.
  const endpoint = String.fromEnvironment('AI_ENDPOINT');
  const appKey = String.fromEnvironment('AI_APP_KEY');
  try {
    final google = await GoogleServices.initialize();
    final store = AppStore(
      google: google,
      advisor: endpoint.isEmpty
          ? null
          : PersonalizationClient(
              endpoint,
              tokenProvider: google?.idToken,
              appKey: appKey,
            ),
      extractor: endpoint.isEmpty
          ? null
          : CloudRunAiExtractor(
              baseUrl: endpoint,
              appKey: appKey,
              tokenProvider: google?.idToken,
            ),
    )..load();
    if (store.extractor is CloudRunAiExtractor) {
      (store.extractor as CloudRunAiExtractor).businessContext = () =>
          store.businessContext;
    }
    runApp(WarungPilotApp(store: store));
  } catch (e) {
    runApp(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LocalText(
                    'Google belum dapat dihubungkan',
                    style: TextStyle(fontSize: 22),
                  ),
                  const SizedBox(height: 12),
                  LocalText('$e'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: main,
                    child: const LocalText('Coba lagi'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WarungPilotApp extends StatelessWidget {
  final AppStore store;
  const WarungPilotApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: store,
      child: AnimatedBuilder(
        animation: store,
        builder: (context, _) => MaterialApp(
          title: 'Retailee',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          locale: Locale(store.languageCode),
          supportedLocales: const [Locale('id'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          // Constrain to phone width when previewed on web/desktop.
          builder: (context, child) => ColoredBox(
            color: const Color(0xFFECEBF5),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: ClipRect(child: child),
              ),
            ),
          ),
          home: const RootGate(),
        ),
      ),
    );
  }
}

class RootGate extends StatelessWidget {
  const RootGate({super.key});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final Widget page;
    if (!store.loaded) {
      page = const Scaffold(
        key: ValueKey('splash'),
        backgroundColor: AppColors.primary,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    } else if (store.loadError != null) {
      page = Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(store.loadError!),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: store.load,
                  child: const LocalText('Muat ulang'),
                ),
                if (store.googleEnabled)
                  TextButton(
                    onPressed: store.signOut,
                    child: const LocalText('Keluar dari Google'),
                  ),
              ],
            ),
          ),
        ),
      );
    } else if (!store.languageChosen) {
      page = const LanguageSetupScreen(key: ValueKey('language'));
    } else if (!store.signedIn) {
      page = const LoginScreen(key: ValueKey('login'));
    } else if (!store.onboarded || store.business?.type == null) {
      page = const BusinessSetupScreen(key: ValueKey('onboarding'));
    } else {
      page = const HomeShell(key: ValueKey('home'));
    }
    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 200),
      child: page,
    );
  }
}
