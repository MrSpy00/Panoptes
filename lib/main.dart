import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final state = ref.watch(panoptesProvider);
    return MaterialApp(
      title: 'Panoptes OSINT',
      debugShowCheckedModeBanner: false,
      themeMode: state.isDarkMode ? ThemeMode.dark : ThemeMode.light,
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

    final tabs = <Widget>[
      const TargetInputTab(),
      const DossierResultsTab(),
      const FaceLabTab(),
      RelationshipGraphAndTimelineTab(
        session: state.currentSession,
        onDeepenPivot: notifier.deepenWithPivot,
      ),
      const VaultConfigTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 62,
        titleSpacing: 16,
        title: Row(
          children: [
            const PanoptesLogo(size: 36, simplified: true),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        strings.appTitle,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.8,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: PanoptesColors.burgundyAbyss,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: PanoptesColors.crimson, width: 0.8),
                        ),
                        child: const Text(
                          'EDGE // OFFLINE',
                          style: TextStyle(
                            color: PanoptesColors.crimsonBright,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    strings.appSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PanoptesColors.textSecondary,
                      fontSize: 9.5,
                      fontFamily: 'monospace',
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Dil Değiştir (TR / EN)',
            onPressed: notifier.toggleLanguage,
            icon: Text(
              state.language.name.toUpperCase(),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: PanoptesColors.crimsonBright,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Tema Değiştir',
            onPressed: notifier.toggleTheme,
            icon: Icon(
              state.isDarkMode ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
              size: 20,
            ),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: PanoptesColors.borderSubtle,
          ),
        ),
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: state.activeTabIndex,
            children: tabs,
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
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: PanoptesColors.borderSubtle, width: 1),
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
    return Container(
      color: Colors.black.withValues(alpha: 0.88),
      padding: const EdgeInsets.all(20),
      alignment: Alignment.center,
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: PanoptesColors.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: PanoptesColors.crimson, width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PanoptesLogo(size: 68, showReticle: true),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: PanoptesColors.crimsonBright,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  body,
                  style: const TextStyle(
                    color: PanoptesColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: onAccept,
                    icon: const Icon(Icons.verified_user_outlined, size: 18),
                    label: Text(acceptLabel),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
