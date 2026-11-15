import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/panoptes_theme.dart';
import '../../domain/models/osint_models.dart';
import '../providers/osint_controller.dart';
import 'webview_recon_sheet.dart';

class DossierResultsTab extends ConsumerWidget {
  const DossierResultsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(panoptesProvider);
    final notifier = ref.read(panoptesProvider.notifier);
    final strings = state.strings;
    final session = state.currentSession;

    if (session == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.manage_search, size: 54, color: PanoptesColors.crimson),
              const SizedBox(height: 12),
              const Text(
                'AKTİF İSTİHBARAT DOSYASI YOK',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.6),
              ),
              const SizedBox(height: 6),
              const Text(
                'Hedef sekmesinden fotoğraf veya kimlik bilgisi girin ya da tek dokunuşla örnek senaryoyu çalıştırın.',
                textAlign: TextAlign.center,
                style: TextStyle(color: PanoptesColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  notifier.loadSampleScenario();
                  notifier.runInvestigation();
                },
                icon: const Icon(Icons.bolt, size: 18),
                label: Text(strings.loadSampleTarget),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = state.filteredFindings;

    return CustomScrollView(
      slivers: [
        // 1. Dossier Summary & Export Bar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: PanoptesColors.surfaceCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: PanoptesColors.borderCrimson, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session.target.displayLabel.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${session.findings.length} Bulgu • ${session.highConfidenceCount} Yüksek Güven • Ort. Skor: %${session.averageConfidence}',
                              style: const TextStyle(
                                color: PanoptesColors.crimsonBright,
                                fontSize: 11.5,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Favorileri Filtrele',
                        onPressed: notifier.toggleFavoritesOnly,
                        icon: Icon(
                          state.favoritesOnly ? Icons.bookmark : Icons.bookmark_border,
                          color: state.favoritesOnly ? PanoptesColors.crimson : PanoptesColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Export Actions Row (Markdown / PDF / JSON)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final md = notifier.exportService.generateMarkdownReport(session);
                            await notifier.exportService.shareTextReport(
                              content: md,
                              subject: 'Panoptes OSINT - ${session.target.displayLabel}.md',
                            );
                          },
                          icon: const Icon(Icons.description_outlined, size: 16),
                          label: const Text('MD', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            await notifier.exportService.previewOrSharePdf(session);
                          },
                          icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                          label: const Text('PDF', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final js = notifier.exportService.generateJsonReport(session);
                            await notifier.exportService.shareTextReport(
                              content: js,
                              subject: 'Panoptes OSINT - ${session.target.displayLabel}.json',
                            );
                          },
                          icon: const Icon(Icons.data_object, size: 16),
                          label: const Text('JSON', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // 2. Recursive Pivot Banner (if any discovered)
        if (session.pivots.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: PanoptesColors.burgundyAbyss.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: PanoptesColors.crimson, width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.alt_route, color: PanoptesColors.crimsonBright, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${strings.pivotDetected}: ${session.pivots.first.value} (${session.pivots.first.reason})',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: () => notifier.deepenWithPivot(session.pivots.first),
                      child: Text(
                        strings.runPivotScan,
                        style: const TextStyle(
                          color: PanoptesColors.crimsonBright,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // 3. Category Filter Chips + Confidence Threshold Slider
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: Column(
              children: [
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _CategoryChip(
                        label: '${strings.catAll} (${session.findings.length})',
                        selected: state.selectedCategory == null,
                        onTap: () => notifier.setCategoryFilter(null),
                      ),
                      _CategoryChip(
                        label: strings.catFace,
                        selected: state.selectedCategory == OsintCategory.faceVisual,
                        onTap: () => notifier.setCategoryFilter(OsintCategory.faceVisual),
                      ),
                      _CategoryChip(
                        label: strings.catSocial,
                        selected: state.selectedCategory == OsintCategory.socialUsername,
                        onTap: () => notifier.setCategoryFilter(OsintCategory.socialUsername),
                      ),
                      _CategoryChip(
                        label: strings.catTurkey,
                        selected: state.selectedCategory == OsintCategory.turkeySpecial,
                        onTap: () => notifier.setCategoryFilter(OsintCategory.turkeySpecial),
                      ),
                      _CategoryChip(
                        label: strings.catCorporate,
                        selected: state.selectedCategory == OsintCategory.corporateAcademic,
                        onTap: () => notifier.setCategoryFilter(OsintCategory.corporateAcademic),
                      ),
                      _CategoryChip(
                        label: strings.catForums,
                        selected: state.selectedCategory == OsintCategory.forumsDictionaries,
                        onTap: () => notifier.setCategoryFilter(OsintCategory.forumsDictionaries),
                      ),
                      _CategoryChip(
                        label: strings.catNews,
                        selected: state.selectedCategory == OsintCategory.newsArchives,
                        onTap: () => notifier.setCategoryFilter(OsintCategory.newsArchives),
                      ),
                      _CategoryChip(
                        label: strings.catEmailPhone,
                        selected: state.selectedCategory == OsintCategory.emailPhoneDork,
                        onTap: () => notifier.setCategoryFilter(OsintCategory.emailPhoneDork),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Text(
                      'Min. Güven Skoru:',
                      style: TextStyle(fontSize: 11.5, color: PanoptesColors.textSecondary),
                    ),
                    Expanded(
                      child: Slider(
                        value: state.minConfidenceFilter.toDouble(),
                        min: 0,
                        max: 95,
                        divisions: 19,
                        activeColor: PanoptesColors.crimson,
                        label: '%${state.minConfidenceFilter}',
                        onChanged: (v) => notifier.setMinConfidenceFilter(v.round()),
                      ),
                    ),
                    Text(
                      '%${state.minConfidenceFilter}+',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // 4. High-Density Tactical Intelligence Finding Cards
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
          sliver: SliverList.separated(
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = filtered[index];
              return _FindingIntelCard(
                finding: item,
                onToggleFavorite: () => notifier.toggleFindingFavorite(item.id),
                onOpenWebViewBridge: () {
                  WebViewReconSheet.open(
                    context,
                    url: item.url,
                    title: item.sourceName,
                    onVerifyCandidateImage: (imgUrl) {
                      notifier.compareCandidateFaceUrl(imgUrl);
                      notifier.setActiveTab(2); // Switch to Face Lab tab
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? PanoptesColors.crimson : PanoptesColors.surfaceCard,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected ? PanoptesColors.crimsonBright : PanoptesColors.borderSubtle,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : PanoptesColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _FindingIntelCard extends StatelessWidget {
  final OsintFinding finding;
  final VoidCallback onToggleFavorite;
  final VoidCallback onOpenWebViewBridge;

  const _FindingIntelCard({
    required this.finding,
    required this.onToggleFavorite,
    required this.onOpenWebViewBridge,
  });

  @override
  Widget build(BuildContext context) {
    final score = finding.confidenceScore;
    final badgeColor = score >= 85
        ? PanoptesColors.statusHigh
        : (score >= 70 ? PanoptesColors.crimson : PanoptesColors.statusMedium);

    return Container(
      decoration: BoxDecoration(
        color: PanoptesColors.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: finding.isFavorite ? PanoptesColors.crimson : PanoptesColors.borderSubtle,
          width: finding.isFavorite ? 1.4 : 1.0,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Metadata Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: badgeColor, width: 1),
                ),
                child: Text(
                  'GÜVEN %$score',
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  finding.sourceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PanoptesColors.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              InkWell(
                onTap: onToggleFavorite,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    finding.isFavorite ? Icons.bookmark : Icons.bookmark_border,
                    size: 19,
                    color: finding.isFavorite ? PanoptesColors.crimson : PanoptesColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Title & Subtitle
          Text(
            finding.title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            finding.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: PanoptesColors.crimsonBright,
              fontSize: 11.5,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 8),

          // Snippet
          Text(
            finding.snippet,
            style: const TextStyle(
              color: PanoptesColors.textSecondary,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),

          // Matched Pivot Chips + Fallback Layer Badge
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...finding.matchedFields.map(
                (m) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: PanoptesColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: PanoptesColors.borderStrong, width: 0.8),
                  ),
                  child: Text(
                    m,
                    style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace'),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: PanoptesColors.burgundyAbyss,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  finding.fallbackLayer,
                  style: const TextStyle(
                    fontSize: 10,
                    color: PanoptesColors.crimsonBright,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),

          // Action Buttons Row (WebView Recon Bridge / Direct Link / Wayback Archive)
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenWebViewBridge,
                  icon: const Icon(Icons.radar, size: 16, color: PanoptesColors.crimson),
                  label: const Text('WebView Köprüsü', style: TextStyle(fontSize: 11.5)),
                ),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: () async {
                  final uri = Uri.tryParse(finding.url);
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: const Text('Kaynak', style: TextStyle(fontSize: 11.5)),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: () async {
                  final uri = Uri.tryParse(finding.archiveUrl);
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: const Text('Wayback', style: TextStyle(fontSize: 11.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
