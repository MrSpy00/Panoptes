import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/panoptes_theme.dart';
import '../../domain/models/osint_models.dart';

class RelationshipGraphAndTimelineTab extends StatefulWidget {
  final InvestigationSession? session;
  final GraphLayoutMode layoutMode;
  final void Function(GraphLayoutMode mode) onLayoutModeChanged;
  final void Function(DiscoveredPivot pivot) onDeepenPivot;

  const RelationshipGraphAndTimelineTab({
    super.key,
    required this.session,
    required this.layoutMode,
    required this.onLayoutModeChanged,
    required this.onDeepenPivot,
  });

  @override
  State<RelationshipGraphAndTimelineTab> createState() =>
      _RelationshipGraphAndTimelineTabState();
}

class _RelationshipGraphAndTimelineTabState
    extends State<RelationshipGraphAndTimelineTab> {
  String? _selectedNodeId;
  String _typeFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final p = PanoptesPalette.of(context);
    final session = widget.session;
    if (session == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'İlişki grafiği, çapraz hesap korelasyonu ve zaman çizelgesi üretmek için önce bir hedef taraması başlatın.',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.textSecondary, fontSize: 14),
          ),
        ),
      );
    }

    final filteredNodes = session.graphNodes.where((n) {
      if (n.type == 'target') return true;
      if (_typeFilter == 'all') return true;
      if (_typeFilter == 'verified' && n.type == 'verified_source') return true;
      if (_typeFilter == 'identity' &&
          (n.type == 'username' || n.type == 'email' || n.type == 'phone')) {
        return true;
      }
      if (_typeFilter == 'bio_loc' &&
          (n.type == 'biometric' || n.type == 'location')) {
        return true;
      }
      if (_typeFilter == 'pivot' && n.type == 'pivot') return true;
      return false;
    }).toList();

    final visibleIds = filteredNodes.map((e) => e.id).toSet();
    final filteredEdges = session.graphEdges
        .where((e) => visibleIds.contains(e.fromId) && visibleIds.contains(e.toId))
        .toList();

    final selectedNode = filteredNodes
            .where((n) => n.id == _selectedNodeId)
            .firstOrNull ??
        filteredNodes.firstOrNull;

    final (samePersonScore, correlationEvidence) = _computeSamePersonCorrelation(session);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
      children: [
        // 1. Interactive Relationship & Alias Graph 2.0 Card
        Container(
          decoration: BoxDecoration(
            color: p.surfaceCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: p.borderSubtle, width: 1),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.hub_outlined, color: PanoptesColors.crimson, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'İLİŞKİ & ALIAS GRAFİĞİ 2.0 (ZOOM / PAN)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${filteredNodes.length} Düğüm • ${filteredEdges.length} Bağ',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontFamily: 'monospace',
                      color: p.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Layout Mode Switcher (Radial / Hierarchical / Force-Directed)
              Row(
                children: [
                  _LayoutModeButton(
                    label: 'Radyal',
                    icon: Icons.radar,
                    selected: widget.layoutMode == GraphLayoutMode.radial,
                    onTap: () => widget.onLayoutModeChanged(GraphLayoutMode.radial),
                  ),
                  const SizedBox(width: 6),
                  _LayoutModeButton(
                    label: 'Hiyerarşik',
                    icon: Icons.account_tree_outlined,
                    selected: widget.layoutMode == GraphLayoutMode.hierarchical,
                    onTap: () => widget.onLayoutModeChanged(GraphLayoutMode.hierarchical),
                  ),
                  const SizedBox(width: 6),
                  _LayoutModeButton(
                    label: 'Kuvvet Kümesi',
                    icon: Icons.auto_awesome_mosaic_outlined,
                    selected: widget.layoutMode == GraphLayoutMode.forceDirected,
                    onTap: () => widget.onLayoutModeChanged(GraphLayoutMode.forceDirected),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Node Type Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChipBtn(
                      label: 'Tümü',
                      selected: _typeFilter == 'all',
                      onTap: () => setState(() => _typeFilter = 'all'),
                    ),
                    _FilterChipBtn(
                      label: 'Canlı Doğrulanan',
                      selected: _typeFilter == 'verified',
                      onTap: () => setState(() => _typeFilter = 'verified'),
                    ),
                    _FilterChipBtn(
                      label: 'Kimlik & Nick',
                      selected: _typeFilter == 'identity',
                      onTap: () => setState(() => _typeFilter = 'identity'),
                    ),
                    _FilterChipBtn(
                      label: 'Biyometri & Konum',
                      selected: _typeFilter == 'bio_loc',
                      onTap: () => setState(() => _typeFilter = 'bio_loc'),
                    ),
                    _FilterChipBtn(
                      label: 'Keşfedilen Pivotlar',
                      selected: _typeFilter == 'pivot',
                      onTap: () => setState(() => _typeFilter = 'pivot'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                height: 300,
                decoration: BoxDecoration(
                  color: p.surfaceBase,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: p.borderSubtle),
                ),
                clipBehavior: Clip.antiAlias,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final canvasWidth = constraints.maxWidth;
                    const canvasHeight = 300.0;
                    final size = Size(canvasWidth, canvasHeight);
                    final positions = _computeNodePositions(
                      filteredNodes,
                      size,
                      widget.layoutMode,
                    );
                    return InteractiveViewer(
                      boundaryMargin: const EdgeInsets.all(60),
                      minScale: 0.85,
                      maxScale: 2.5,
                      child: GestureDetector(
                        onTapDown: (details) {
                          final tap = details.localPosition;
                          for (final entry in positions.entries) {
                            if ((entry.value - tap).distance <= 30) {
                              setState(() => _selectedNodeId = entry.key);
                              break;
                            }
                          }
                        },
                        child: CustomPaint(
                          size: size,
                          painter: _OsintGraphPainter(
                            nodes: filteredNodes,
                            edges: filteredEdges,
                            positions: positions,
                            selectedNodeId: selectedNode?.id,
                            layoutMode: widget.layoutMode,
                            palette: p,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (selectedNode != null) ...[
                const Divider(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: p.crimsonTintBg,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: PanoptesColors.crimson, width: 1),
                      ),
                      child: Text(
                        selectedNode.type.toUpperCase(),
                        style: TextStyle(
                          color: p.crimsonText,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        selectedNode.label,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: p.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Güven: %${selectedNode.confidence}',
                      style: const TextStyle(
                        color: PanoptesColors.statusHigh,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. "BU İKİ HESAP AYNI KİŞİ Mİ?" Cross-Platform Identity Correlation Card
        Container(
          decoration: BoxDecoration(
            color: p.surfaceCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: PanoptesColors.statusHigh, width: 1.2),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.fingerprint, color: PanoptesColors.statusHigh, size: 19),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ÇAPRAZ HESAP KORELASYONU: "AYNI KİŞİ Mİ?"',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: PanoptesColors.statusHigh.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: PanoptesColors.statusHigh),
                    ),
                    child: Text(
                      '%$samePersonScore EŞLEŞME',
                      style: const TextStyle(
                        color: PanoptesColors.statusHigh,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...correlationEvidence.map(
                (ev) => Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    '• $ev',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: p.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 3. Recursive Pivot Engine Section
        if (session.pivots.isNotEmpty) ...[
          Container(
            decoration: BoxDecoration(
              color: p.surfaceCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: p.borderCrimson, width: 1),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.alt_route, color: PanoptesColors.crimson, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'KEŞFEDİLEN YENİ PİVOTLAR (ALIAS EXPANSION)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: p.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Derinlik: ${session.target.pivotDepth}/3',
                      style: TextStyle(
                        color: p.crimsonText,
                        fontSize: 11,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...session.pivots.map(
                  (piv) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: p.surfaceBase,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: p.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '[${piv.type.name.toUpperCase()}] ${piv.value}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                    color: p.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  piv.reason,
                                  style: TextStyle(
                                    color: p.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: PanoptesColors.crimsonDeep,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 36),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            onPressed: piv.depth <= 3
                                ? () => widget.onDeepenPivot(piv)
                                : null,
                            child: const Text(
                              'Derinleştir',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // 4. Chronological Intelligence Timeline Fusion
        Container(
          decoration: BoxDecoration(
            color: p.surfaceCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: p.borderSubtle, width: 1),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.timeline, color: PanoptesColors.crimson, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ZAMAN ÇİZELGESİ BİRLEŞTİRME (TIMELINE FUSION)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (session.timeline.isEmpty)
                Text(
                  'Bu oturumda tarih damgalı olay (EXIF / Hesap Açılış / WHOIS) bulunamadı.',
                  style: TextStyle(fontSize: 12, color: p.textSecondary),
                )
              else
                ...session.timeline.map(
                  (ev) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: PanoptesColors.crimson,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Container(
                              width: 1.5,
                              height: 44,
                              color: p.borderStrong,
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    ev.dateLabel,
                                    style: TextStyle(
                                      color: p.crimsonText,
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      ev.source,
                                      textAlign: TextAlign.end,
                                      style: TextStyle(
                                        color: p.textMuted,
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                ev.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                  color: p.textPrimary,
                                ),
                              ),
                              Text(
                                ev.detail,
                                style: TextStyle(
                                  color: p.textSecondary,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
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
    );
  }

  (int, List<String>) _computeSamePersonCorrelation(InvestigationSession session) {
    final evidence = <String>[];
    final verified = session.findings.where((f) => f.isLiveVerified).toList();
    if (verified.isNotEmpty) {
      evidence.add(
        '${verified.length} farklı canlı API kaynağında (${verified.map((e) => e.sourceName.replaceAll(" (Canlı)", "")).take(4).join(", ")}) aynı kimlik/nick izi doğrulandı.',
      );
    }
    if (session.faceAnalysis != null) {
      evidence.add(
        'Biyometrik 192-D yüz vektörü ve 64-bit dHash (${session.faceAnalysis!.dHashHex}) ile görsel kimlik çıpası oluşturuldu.',
      );
    }
    final commitOrEmailPivots =
        session.pivots.where((p) => p.type == PivotType.email).toList();
    if (commitOrEmailPivots.isNotEmpty) {
      evidence.add(
        'Kod/Kayıt loglarından keşfedilen e-posta adresleri (${commitOrEmailPivots.map((e) => e.value).join(", ")}) hesapları birbirine bağlıyor.',
      );
    }
    if (session.target.cityOrHometown.isNotEmpty) {
      evidence.add(
        'Coğrafi Kümeleme (Location Cluster): "${session.target.cityOrHometown}" konumu ile sosyal/kurumsal kayıtlar örtüşüyor.',
      );
    }
    if (evidence.isEmpty) {
      evidence.add('Mevcut isim, nick ve konum parametreleri üzerinden temel korelasyon kuruldu.');
    }
    final score = (session.averageConfidence + (verified.length * 2)).clamp(55, 98);
    return (score, evidence);
  }

  Map<String, Offset> _computeNodePositions(
    List<GraphNode> nodes,
    Size size,
    GraphLayoutMode mode,
  ) {
    final map = <String, Offset>{};
    if (nodes.isEmpty) return map;
    final center = Offset(size.width / 2, size.height / 2);

    if (mode == GraphLayoutMode.hierarchical) {
      // Top-down tree layout
      map[nodes.first.id] = Offset(size.width / 2, 42);
      final others = nodes.skip(1).toList();
      final row1 = others.take((others.length / 2).ceil()).toList();
      final row2 = others.skip(row1.length).toList();
      for (int i = 0; i < row1.length; i++) {
        final x = (size.width / (row1.length + 1)) * (i + 1);
        map[row1[i].id] = Offset(x, 145);
      }
      for (int i = 0; i < row2.length; i++) {
        final x = (size.width / (row2.length + 1)) * (i + 1);
        map[row2[i].id] = Offset(x, 240);
      }
      return map;
    }

    if (mode == GraphLayoutMode.forceDirected) {
      // Clustered organic layout
      map[nodes.first.id] = center;
      final others = nodes.skip(1).toList();
      for (int i = 0; i < others.length; i++) {
        final goldenAngle = i * 2.39996;
        final r = 48.0 + 18.0 * math.sqrt(i + 1);
        map[others[i].id] = Offset(
          (center.dx + r * 1.25 * math.cos(goldenAngle)).clamp(48.0, size.width - 48.0),
          (center.dy + r * 0.85 * math.sin(goldenAngle)).clamp(36.0, size.height - 36.0),
        );
      }
      return map;
    }

    // Default: Radial layout
    map[nodes.first.id] = center;
    final others = nodes.skip(1).toList();
    final radiusX = size.width * 0.31;
    final radiusY = size.height * 0.33;
    for (int i = 0; i < others.length; i++) {
      final angle = (2 * math.pi * i / others.length) - (math.pi / 2);
      final factor = (i % 2 == 0) ? 1.0 : 0.72;
      map[others[i].id] = Offset(
        center.dx + radiusX * factor * math.cos(angle),
        center.dy + radiusY * factor * math.sin(angle),
      );
    }
    return map;
  }
}

class _LayoutModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _LayoutModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = PanoptesPalette.of(context);
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? p.crimson : p.surfaceBase,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: selected ? p.crimson : p.borderSubtle),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: selected ? Colors.white : p.textSecondary),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : p.textSecondary,
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

class _FilterChipBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipBtn({
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
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? p.crimsonTintBg : p.surfaceBase,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: selected ? p.crimson : p.borderSubtle),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: selected ? p.crimsonText : p.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _OsintGraphPainter extends CustomPainter {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final Map<String, Offset> positions;
  final String? selectedNodeId;
  final GraphLayoutMode layoutMode;
  final PanoptesPalette palette;

  const _OsintGraphPainter({
    required this.nodes,
    required this.edges,
    required this.positions,
    required this.layoutMode,
    required this.palette,
    this.selectedNodeId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (layoutMode == GraphLayoutMode.radial) {
      final center = Offset(size.width / 2, size.height / 2);
      final gridPaint = Paint()
        ..color = palette.borderStrong.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawCircle(center, math.min(size.width, size.height) * 0.22, gridPaint);
      canvas.drawCircle(center, math.min(size.width, size.height) * 0.38, gridPaint);
    }

    // Draw Edges
    for (final edge in edges) {
      final p1 = positions[edge.fromId];
      final p2 = positions[edge.toId];
      if (p1 == null || p2 == null) continue;
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = PanoptesColors.crimson.withValues(alpha: 0.48)
          ..strokeWidth = 1.5,
      );
    }

    // Draw Nodes with FULL Labels (Zero .. truncation)
    for (final node in nodes) {
      final pos = positions[node.id];
      if (pos == null) continue;
      final isRoot = node.type == 'target';
      final isSelected = node.id == selectedNodeId;
      final radius = isRoot ? 19.0 : 13.0;

      Color nodeColor = palette.surfaceElevated;
      Color strokeColor = palette.borderStrong;
      if (isRoot) {
        nodeColor = PanoptesColors.crimson;
        strokeColor = Colors.white;
      } else if (node.type == 'biometric') {
        nodeColor = PanoptesColors.burgundyDeep;
        strokeColor = PanoptesColors.crimsonBright;
      } else if (node.type == 'verified_source' || node.type == 'pivot') {
        nodeColor = const Color(0xFF065F46);
        strokeColor = PanoptesColors.statusHigh;
      } else if (isSelected) {
        strokeColor = PanoptesColors.crimson;
      }

      canvas.drawCircle(pos, radius, Paint()..color = nodeColor);
      canvas.drawCircle(
        pos,
        radius,
        Paint()
          ..color = strokeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSelected || isRoot ? 2.2 : 1.2,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: node.label,
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: isRoot ? 9.5 : 8.5,
            fontWeight: isRoot || isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final halfW = tp.width / 2 + 5;
      final minX = math.min(halfW, size.width / 2);
      final maxX = math.max(size.width - halfW, size.width / 2);
      final clampedCenterX = pos.dx.clamp(minX, maxX);
      final clampedCenterY = (pos.dy + radius + 9).clamp(
        tp.height / 2 + 4,
        size.height - tp.height / 2 - 4,
      );

      final bgRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(clampedCenterX, clampedCenterY),
          width: tp.width + 8,
          height: tp.height + 3,
        ),
        const Radius.circular(4),
      );
      canvas.drawRRect(
        bgRect,
        Paint()..color = palette.surfaceCard.withValues(alpha: 0.92),
      );
      tp.paint(
        canvas,
        Offset(clampedCenterX - tp.width / 2, clampedCenterY - tp.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OsintGraphPainter oldDelegate) {
    return oldDelegate.nodes != nodes ||
        oldDelegate.selectedNodeId != selectedNodeId ||
        oldDelegate.layoutMode != layoutMode ||
        oldDelegate.palette.isDark != palette.isDark;
  }
}
