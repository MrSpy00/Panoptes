import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final p = PanoptesPalette.of(context);

    if (session == null) {
      final hasDraft = state.draftTarget.hasAnyIdentityInput;
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.manage_search, size: 54, color: PanoptesColors.crimson),
              const SizedBox(height: 12),
              Text(
                'AKTİF İSTİHBARAT DOSYASI YOK',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: 0.6,
                  color: p.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                hasDraft
                    ? 'Hedef sekmesinde girdiğiniz bilgiler hazır (${state.draftTarget.displayLabel}). Hemen taramayı başlatabilirsiniz.'
                    : 'Hedef sekmesinden fotoğraf veya kimlik bilgisi girin ya da tek dokunuşla örnek senaryoyu çalıştırın.',
                textAlign: TextAlign.center,
                style: TextStyle(color: p.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              if (hasDraft) ...[
                FilledButton(
                  onPressed: () => notifier.runInvestigation(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.radar, size: 18),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Seçili Hedefi Şimdi Tara (${state.draftTarget.displayLabel})',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              OutlinedButton(
                onPressed: () async {
                  await notifier.loadSampleScenario();
                  await notifier.runInvestigation();
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt, size: 18, color: PanoptesColors.crimson),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        strings.loadSampleTarget,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = state.filteredFindings;
    final liveVerifiedCount = session.findings.where((f) => f.isLiveVerified).length;

    return CustomScrollView(
      slivers: [
        // 1. Dossier Header, Template Selector & 4-Format Export Bar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: p.surfaceCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: p.borderCrimson, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  session.target.displayLabel.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                    color: p.textPrimary,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: p.crimsonTintBg,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: p.crimson, width: 0.8),
                                  ),
                                  child: Text(
                                    session.target.workspaceName,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: p.crimsonText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${session.findings.length} Bulgu • $liveVerifiedCount Canlı Doğrulanan • Ort. Güven: %${session.averageConfidence}',
                              style: TextStyle(
                                color: p.crimsonText,
                                fontSize: 11,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Favorileri Filtrele',
                        visualDensity: VisualDensity.compact,
                        onPressed: notifier.toggleFavoritesOnly,
                        icon: Icon(
                          state.favoritesOnly ? Icons.bookmark : Icons.bookmark_border,
                          color: state.favoritesOnly ? PanoptesColors.crimson : p.textSecondary,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Aktif Dosyayı Kapat / Ekranı Temizle',
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          notifier.closeActiveSession();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Aktif dosya kapatıldı (Kasa sekmesinden geçmiş dosyalara ulaşabilirsiniz).',
                              ),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: Icon(Icons.close, color: p.textSecondary, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Report Template Selector
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Text(
                          'Şablon: ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: p.textSecondary,
                          ),
                        ),
                        _TemplateChip(
                          label: 'Teknik Detaylı',
                          selected: state.selectedReportTemplate == ReportTemplate.technical,
                          onTap: () => notifier.setReportTemplate(ReportTemplate.technical),
                        ),
                        _TemplateChip(
                          label: 'Yönetici Özeti',
                          selected: state.selectedReportTemplate == ReportTemplate.executive,
                          onTap: () => notifier.setReportTemplate(ReportTemplate.executive),
                        ),
                        _TemplateChip(
                          label: 'KVKK / Hukuki',
                          selected: state.selectedReportTemplate == ReportTemplate.legalKvkk,
                          onTap: () => notifier.setReportTemplate(ReportTemplate.legalKvkk),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 4-Format Export Actions Row (MD / PDF / HTML / JSON)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
                            minimumSize: const Size(0, 38),
                          ),
                          onPressed: () async {
                            final md = notifier.exportService.generateMarkdownReport(
                              session,
                              template: state.selectedReportTemplate,
                            );
                            await notifier.exportService.shareTextReport(
                              content: md,
                              subject: 'Panoptes OSINT - ${session.target.displayLabel}.md',
                            );
                          },
                          child: const Text(
                            'MD',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
                            minimumSize: const Size(0, 38),
                          ),
                          onPressed: () async {
                            await notifier.exportService.previewOrSharePdf(
                              session,
                              template: state.selectedReportTemplate,
                            );
                          },
                          child: const Text(
                            'PDF',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
                            minimumSize: const Size(0, 38),
                          ),
                          onPressed: () async {
                            final html = notifier.exportService.generateHtmlReport(
                              session,
                              template: state.selectedReportTemplate,
                            );
                            await notifier.exportService.shareTextReport(
                              content: html,
                              subject: 'Panoptes OSINT - ${session.target.displayLabel}.html',
                            );
                          },
                          child: const Text(
                            'HTML',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
                            minimumSize: const Size(0, 38),
                          ),
                          onPressed: () async {
                            final js = notifier.exportService.generateJsonReport(session);
                            await notifier.exportService.shareTextReport(
                              content: js,
                              subject: 'Panoptes OSINT - ${session.target.displayLabel}.json',
                            );
                          },
                          child: const Text(
                            'JSON',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // 2. UPFRONT CONCRETE DISCOVERED FACTS PANEL ("BULUNAN SOMUT BİLGİLER & ÇAPRAZ DOĞRULAMA ÖZETİ")
        if (session.executiveFacts.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: p.surfaceCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: PanoptesColors.statusHigh, width: 1.4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.verified_outlined,
                          color: PanoptesColors.statusHigh,
                          size: 19,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'KEŞFEDİLEN SOMUT BİLGİLER & ÇAPRAZ DOĞRULAMA ÖZETİ',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                              color: p.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...session.executiveFacts.map(
                      (fact) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 5),
                              child: Icon(
                                Icons.circle,
                                size: 6,
                                color: PanoptesColors.statusHigh,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SelectableText(
                                fact,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: p.textPrimary,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (session.diffSummary.isNotEmpty) ...[
                      const Divider(height: 14),
                      Text(
                        'ÖNCEKİ TARAMAYA GÖRE DEĞİŞİM (DIFF):',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                          color: p.crimsonText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...session.diffSummary.map(
                        (d) => Text(
                          '• $d',
                          style: TextStyle(fontSize: 11.5, color: p.textSecondary),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

        // 3. Recursive Pivot Banner (if any discovered)
        if (session.pivots.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: p.crimsonTintBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: p.crimson, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.alt_route, color: p.crimson, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${strings.pivotDetected} (${session.pivots.length} Adet) — Tek Dokunuşla 2. Seviye Taramayı Başlatın:',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: p.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: session.pivots.take(6).map((piv) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              backgroundColor: p.surfaceCard,
                              side: BorderSide(color: p.crimson),
                              label: Text(
                                '${piv.type.name.toUpperCase()}: ${piv.value}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: p.textPrimary,
                                ),
                              ),
                              onPressed: () => notifier.deepenWithPivot(piv),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // 4. Category Filter Chips + Confidence Threshold Slider
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _CategoryChip(
                        label: '${strings.catAll} (${session.findings.length})',
                        selected: state.selectedCategory == null,
                        onTap: () => notifier.setCategoryFilter(null),
                      ),
                      _CategoryChip(
                        label: strings.catFace,
                        selected: state.selectedCategory == OsintCategory.visualAndFace,
                        onTap: () => notifier.setCategoryFilter(OsintCategory.visualAndFace),
                      ),
                      _CategoryChip(
                        label: strings.catSocial,
                        selected: state.selectedCategory == OsintCategory.usernameAndSocial,
                        onTap: () => notifier.setCategoryFilter(OsintCategory.usernameAndSocial),
                      ),
                      _CategoryChip(
                        label: strings.catDomainInfra,
                        selected: state.selectedCategory == OsintCategory.domainAndInfra,
                        onTap: () => notifier.setCategoryFilter(OsintCategory.domainAndInfra),
                      ),
                      _CategoryChip(
                        label: strings.catEmailPhone,
                        selected: state.selectedCategory == OsintCategory.emailAndPhone,
                        onTap: () => notifier.setCategoryFilter(OsintCategory.emailAndPhone),
                      ),
                      _CategoryChip(
                        label: strings.catTurkey,
                        selected: state.selectedCategory == OsintCategory.turkeyRegional,
                        onTap: () => notifier.setCategoryFilter(OsintCategory.turkeyRegional),
                      ),
                      _CategoryChip(
                        label: strings.catDocuments,
                        selected: state.selectedCategory == OsintCategory.documentsAndDorks,
                        onTap: () => notifier.setCategoryFilter(OsintCategory.documentsAndDorks),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'Min. Güven:',
                      style: TextStyle(fontSize: 11.5, color: p.textSecondary),
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
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: p.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // 5. High-Signal Finding Cards with Upfront Extracted Key-Value Tables
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 100),
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
                      notifier.setActiveTab(2);
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

class _TemplateChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TemplateChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = PanoptesPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? p.crimson : p.surfaceBase,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: selected ? p.crimson : p.borderSubtle),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : p.textSecondary,
            ),
          ),
        ),
      ),
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
    final p = PanoptesPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? PanoptesColors.crimson : p.surfaceCard,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected ? PanoptesColors.crimsonBright : p.borderSubtle,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : p.textSecondary,
              fontSize: 11.5,
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
    final p = PanoptesPalette.of(context);
    final score = finding.confidenceScore;
    final badgeColor = score >= 85
        ? PanoptesColors.statusHigh
        : (score >= 70 ? PanoptesColors.crimson : PanoptesColors.statusMedium);

    return Container(
      decoration: BoxDecoration(
        color: p.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: finding.isFavorite
              ? PanoptesColors.crimson
              : (finding.isLiveVerified ? PanoptesColors.statusHigh.withValues(alpha: 0.6) : p.borderSubtle),
          width: finding.isFavorite || finding.isLiveVerified ? 1.3 : 1.0,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Metadata Row (Zero ellipsis cutoff)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: badgeColor, width: 1),
                ),
                child: Text(
                  'GÜVEN %$score',
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              if (finding.isLiveVerified) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: PanoptesColors.statusHigh.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: PanoptesColors.statusHigh, width: 0.8),
                  ),
                  child: const Text(
                    'CANLI VERİ',
                    style: TextStyle(
                      color: PanoptesColors.statusHigh,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  finding.sourceName,
                  style: TextStyle(
                    color: p.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  final textToCopy = [
                    finding.title,
                    ...finding.extractedData.entries.map((e) => '${e.key}: ${e.value}'),
                    finding.url,
                  ].join('\n');
                  Clipboard.setData(ClipboardData(text: textToCopy));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Bulgu bilgileri panoya kopyalandı.'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.copy_outlined, size: 17, color: p.textMuted),
                ),
              ),
              InkWell(
                onTap: onToggleFavorite,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    finding.isFavorite ? Icons.bookmark : Icons.bookmark_border,
                    size: 19,
                    color: finding.isFavorite ? PanoptesColors.crimson : p.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Full Title (Never truncated)
          Text(
            finding.title,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              height: 1.25,
              color: p.textPrimary,
            ),
          ),

          // Score 2.0 Breakdown
          if (finding.scoreBreakdown.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              finding.scoreBreakdown,
              style: TextStyle(
                color: p.crimsonText,
                fontSize: 10.5,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
              ),
            ),
          ],

          // UPFRONT CONCRETE EXTRACTED DATA TABLE (Shown BEFORE snippet & links!)
          if (finding.extractedData.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: p.surfaceBase,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: p.borderStrong, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ÇIKARILAN SOMUT VERİLER:',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace',
                      color: p.crimsonText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...finding.extractedData.entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 125,
                            child: Text(
                              '${entry.key}:',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: p.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: SelectableText(
                              entry.value,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace',
                                color: p.textPrimary,
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
          ],

          const SizedBox(height: 8),
          // Explanation / Snippet
          Text(
            finding.snippet,
            style: TextStyle(
              color: p.textSecondary,
              fontSize: 12,
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
                    color: p.surfaceElevated,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: p.borderStrong, width: 0.8),
                  ),
                  child: Text(
                    m,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontFamily: 'monospace',
                      color: p.textPrimary,
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: p.crimsonTintBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  finding.fallbackLayer,
                  style: TextStyle(
                    fontSize: 10,
                    color: p.crimsonText,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
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
                flex: 3,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    minimumSize: const Size(0, 36),
                  ),
                  onPressed: onOpenWebViewBridge,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.radar, size: 15, color: PanoptesColors.crimson),
                      SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'WebView İncele',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    minimumSize: const Size(0, 36),
                  ),
                  onPressed: () async {
                    final uri = Uri.tryParse(finding.url);
                    if (uri != null) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  child: const Text(
                    'Kaynak',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    minimumSize: const Size(0, 36),
                  ),
                  onPressed: () async {
                    final uri = Uri.tryParse(finding.archiveUrl);
                    if (uri != null) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  child: const Text(
                    'Wayback',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
