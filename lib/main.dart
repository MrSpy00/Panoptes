import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'core/l10n/app_strings.dart';
import 'core/theme/panoptes_theme.dart';
import 'core/widgets/panoptes_logo.dart';
import 'features/osint/presentation/providers/osint_controller.dart';
import 'features/osint/presentation/widgets/dossier_results_tab.dart';
import 'features/osint/presentation/widgets/face_lab_tab.dart';
import 'features/osint/presentation/widgets/relationship_graph_view.dart';
import 'features/osint/presentation/widgets/target_input_tab.dart';
import 'features/osint/presentation/widgets/vault_config_tab.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: PanoptesApp(),
    ),
  );
}

class PanoptesApp extends ConsumerWidget {
  const PanoptesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(panoptesProvider.select((s) => s.isDarkMode));
    return MaterialApp(
      title: 'Panoptes OSINT',
      debugShowCheckedModeBanner: false,
      themeAnimationDuration: Duration.zero,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      darkTheme: PanoptesTheme.darkTheme,
      theme: PanoptesTheme.lightTheme,
      home: const PanoptesShellScreen(),
    );
  }
}

class PanoptesShellScreen extends ConsumerWidget {
  const PanoptesShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(panoptesProvider);
    final notifier = ref.read(panoptesProvider.notifier);
    final strings = state.strings;
    final p = PanoptesPalette.of(context);

    Widget activeView;
    switch (state.activeTabIndex) {
      case 0:
        activeView = const TargetInputTab(key: ValueKey('tab_0'));
        break;
      case 1:
        activeView = const DossierResultsTab(key: ValueKey('tab_1'));
        break;
      case 2:
        activeView = const FaceLabTab(key: ValueKey('tab_2'));
        break;
      case 3:
        activeView = RelationshipGraphAndTimelineTab(
          key: const ValueKey('tab_3'),
          session: state.currentSession,
          layoutMode: state.graphLayoutMode,
          onLayoutModeChanged: notifier.setGraphLayoutMode,
          onDeepenPivot: notifier.deepenWithPivot,
        );
        break;
      case 4:
      default:
        activeView = const VaultConfigTab(key: ValueKey('tab_4'));
        break;
    }

    final flagAsset = state.language == AppLanguage.tr
        ? 'assets/branding/flag_tr.svg'
        : 'assets/branding/flag_en.svg';

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 60,
        titleSpacing: 12,
        title: Row(
          children: [
            const AnimatedPanoptesLogo(size: 34, simplified: true),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          strings.appTitle,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                            color: p.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: p.crimsonTintBg,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: p.crimson, width: 0.8),
                        ),
                        child: Text(
                          'v2.0 EDGE',
                          style: TextStyle(
                            color: p.crimsonText,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      strings.appSubtitle,
                      style: TextStyle(
                        color: p.textSecondary,
                        fontSize: 9.5,
                        fontFamily: 'monospace',
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // SVG Flag Language Toggle Button
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: notifier.toggleLanguage,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: p.surfaceCard,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: p.borderStrong, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: SvgPicture.asset(
                        flagAsset,
                        width: 20,
                        height: 14,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      state.language.name.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        color: p.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: strings.isTr ? 'Tema Değiştir' : 'Toggle Theme',
            onPressed: notifier.toggleTheme,
            icon: Icon(
              state.isDarkMode ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
              size: 20,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: p.borderSubtle,
          ),
        ),
      ),
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            child: activeView,
          ),
          if (!state.ethicsAccepted)
            _EthicsConsentOverlay(
              title: strings.ethicsTitle,
              body: strings.ethicsBody,
              acceptLabel: strings.ethicsAccept,
              onAccept: notifier.acceptEthics,
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: p.borderSubtle, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: state.activeTabIndex,
          onTap: notifier.setActiveTab,
          selectedFontSize: 11,
          unselectedFontSize: 10.5,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.radar_outlined),
              activeIcon: const Icon(Icons.radar),
              label: strings.navAcquire,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.view_module_outlined),
              activeIcon: const Icon(Icons.view_module),
              label: strings.navDossier,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.face_retouching_natural_outlined),
              activeIcon: const Icon(Icons.face_retouching_natural),
              label: strings.navFaceLab,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.hub_outlined),
              activeIcon: const Icon(Icons.hub),
              label: strings.navGraph,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.shield_outlined),
              activeIcon: const Icon(Icons.shield),
              label: strings.navVault,
            ),
          ],
        ),
      ),
    );
  }
}

class _EthicsConsentOverlay extends StatelessWidget {
  final String title;
  final String body;
  final String acceptLabel;
  final VoidCallback onAccept;

  const _EthicsConsentOverlay({
    required this.title,
    required this.body,
    required this.acceptLabel,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final p = PanoptesPalette.of(context);
    return Container(
      color: Colors.black.withValues(alpha: 0.86),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 540),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: p.surfaceCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: p.crimson, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AnimatedPanoptesLogo(size: 58, showReticle: true),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: p.crimsonText,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    body,
                    style: TextStyle(
                      color: p.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  onPressed: onAccept,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.verified_user_outlined, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          acceptLabel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
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
