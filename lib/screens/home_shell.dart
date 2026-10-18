import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/retail_glyph.dart';
import 'core_home_screen.dart';
import 'journal_screen.dart';
import 'scan_screen.dart';
import 'missions_screen.dart';
import 'report_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  static void goTo(BuildContext context, int index) =>
      context.findAncestorStateOfType<_HomeShellState>()?._go(index);
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  late final _arrival = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    value: 1,
  );
  late final _opacity = Tween(
    begin: .45,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _arrival, curve: Curves.easeOut));

  void _go(int index) {
    if (index == _index || index < 0 || index > 4) return;
    setState(() => _index = index);
    if (MediaQuery.disableAnimationsOf(context)) {
      _arrival.value = 1;
    } else {
      _arrival.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _arrival.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    const pages = [
      CoreHomeScreen(),
      JournalScreen(),
      ScanScreen(),
      ReportScreen(),
      MissionsScreen(),
    ];
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _index != 0) _go(0);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FC),
        body: FadeTransition(
          opacity: _opacity,
          child: IndexedStack(
            index: _index,
            children: [
              for (var i = 0; i < pages.length; i++)
                TickerMode(enabled: _index == i, child: pages[i]),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(12, 6, 12, 8),
          child: Material(
            color: const Color(0xFF211B32),
            elevation: 6,
            shadowColor: const Color(0x30211B32),
            borderRadius: BorderRadius.circular(26),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _tab(0, 'Beranda', RetailGlyphKind.shop),
                    _tab(
                      1,
                      'Jurnal',
                      RetailGlyphKind.shelf,
                      badge: store.openDrafts.length,
                    ),
                    _tab(2, 'Foto', RetailGlyphKind.capture),
                    _tab(3, 'Laporan', RetailGlyphKind.report),
                    _tab(
                      4,
                      'Misi',
                      RetailGlyphKind.tasks,
                      badge: store.claimableCount,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(int index, String label, RetailGlyphKind glyph, {int badge = 0}) {
    final selected = _index == index;
    final capture = index == 2;
    final motion = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    final foreground = selected
        ? (capture ? const Color(0xFF4A3000) : const Color(0xFF211B32))
        : const Color(0xFFE1DCEB);
    return Expanded(
      child: Semantics(
        selected: selected,
        child: InkWell(
          key: ValueKey('main-tab-$index'),
          borderRadius: BorderRadius.circular(20),
          onTap: () => _go(index),
          focusColor: const Color(0xFF57468E),
          hoverColor: const Color(0xFF393049),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Badge(
                    isLabelVisible: badge > 0,
                    backgroundColor: AppColors.accent,
                    textColor: const Color(0xFF4A3000),
                    label: Text('$badge', style: const TextStyle(fontSize: 11)),
                    child: AnimatedContainer(
                      duration: motion,
                      curve: Curves.easeOut,
                      width: 48,
                      height: 36,
                      decoration: BoxDecoration(
                        color: selected
                            ? (capture
                                  ? AppColors.accent
                                  : const Color(0xFFDCD3FF))
                            : (capture
                                  ? const Color(0xFF57468E)
                                  : Colors.transparent),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: index == 1
                            ? Icon(
                                Icons.menu_book_outlined,
                                color: foreground,
                                size: 24,
                              )
                            : RetailGlyph(glyph, color: foreground),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  LocalText(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.2,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? Colors.white : const Color(0xFFCCC5D9),
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
}
