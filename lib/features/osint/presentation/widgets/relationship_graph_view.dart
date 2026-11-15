import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/panoptes_theme.dart';
import '../../domain/models/osint_models.dart';

class RelationshipGraphAndTimelineTab extends StatefulWidget {
  final InvestigationSession? session;
  final void Function(DiscoveredPivot pivot) onDeepenPivot;

  const RelationshipGraphAndTimelineTab({
    super.key,
    required this.session,
    required this.onDeepenPivot,
  });

  @override
  State<RelationshipGraphAndTimelineTab> createState() =>
      _RelationshipGraphAndTimelineTabState();
}

class _RelationshipGraphAndTimelineTabState
    extends State<RelationshipGraphAndTimelineTab> {
  String? _selectedNodeId;

  @override
  Widget build(BuildContext context) {
    final p = PanoptesPalette.of(context);
    final session = widget.session;
    if (session == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'İlişki grafiği ve zaman çizelgesi üretmek için önce bir hedef taraması başlatın.',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.textSecondary, fontSize: 14),
          ),
        ),
      );
    }

    final selectedNode = session.graphNodes
            .where((n) => n.id == _selectedNodeId)
            .firstOrNull ??
        session.graphNodes.firstOrNull;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
      children: [
        // 1. Interactive Radial Relationship & Alias Graph Card
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
                      'İLİŞKİ & ALIAS GRAFİĞİ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${session.graphNodes.length} Düğüm • ${session.graphEdges.length} Bağ',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontFamily: 'monospace',
                      color: p.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 280,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = Size(constraints.maxWidth, 280);
                    final positions = _computeNodePositions(session.graphNodes, size);
                    return GestureDetector(
                      onTapDown: (details) {
                        final tap = details.localPosition;
                        for (final entry in positions.entries) {
                          if ((entry.value - tap).distance <= 28) {
                            setState(() => _selectedNodeId = entry.key);
                            break;
                          }
                        }
                      },
                      child: CustomPaint(
                        size: size,
                        painter: _OsintGraphPainter(
                          nodes: session.graphNodes,
                          edges: session.graphEdges,
                          positions: positions,
                          selectedNodeId: selectedNode?.id,
                          palette: p,
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
                        color: p.isDark
                            ? PanoptesColors.burgundyAbyss
                            : const Color(0xFFFFE4E6),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: PanoptesColors.crimson, width: 1),
                      ),
                      child: Text(
                        selectedNode.type.toUpperCase(),
                        style: TextStyle(
                          color: p.isDark
                              ? PanoptesColors.crimsonBright
                              : PanoptesColors.crimsonDeep,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

        // 2. Recursive Pivot Engine Section
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
                        'KEŞFEDİLEN YENİ PİVOTLAR',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: p.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Derinlik: ${session.target.pivotDepth}/3',
                      style: TextStyle(
                        color: p.isDark
                            ? PanoptesColors.crimsonBright
                            : PanoptesColors.crimsonDeep,
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

        // 3. Chronological Intelligence Timeline
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
                      'ZAMAN ÇİZELGESİ (TIMELINE)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
                                    color: p.isDark
                                        ? PanoptesColors.crimsonBright
                                        : PanoptesColors.crimsonDeep,
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
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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

  Map<String, Offset> _computeNodePositions(List<GraphNode> nodes, Size size) {
    final map = <String, Offset>{};
    if (nodes.isEmpty) return map;
    final center = Offset(size.width / 2, size.height / 2);
    map[nodes.first.id] = center;

    final others = nodes.skip(1).toList();
    final radius = math.min(size.width, size.height) * 0.35;
    for (int i = 0; i < others.length; i++) {
      final angle = (2 * math.pi * i / others.length) - (math.pi / 2);
      final r = (i % 2 == 0) ? radius : radius * 0.76;
      map[others[i].id] = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
    }
    return map;
  }
}

class _OsintGraphPainter extends CustomPainter {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final Map<String, Offset> positions;
  final String? selectedNodeId;
  final PanoptesPalette palette;

  const _OsintGraphPainter({
    required this.nodes,
    required this.edges,
    required this.positions,
    required this.palette,
    this.selectedNodeId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final gridPaint = Paint()
      ..color = palette.borderStrong.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, math.min(size.width, size.height) * 0.20, gridPaint);
    canvas.drawCircle(center, math.min(size.width, size.height) * 0.36, gridPaint);

    // Draw Edges
    for (final edge in edges) {
      final p1 = positions[edge.fromId];
      final p2 = positions[edge.toId];
      if (p1 == null || p2 == null) continue;
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = PanoptesColors.crimson.withValues(alpha: 0.45)
          ..strokeWidth = 1.5,
      );
    }

    // Draw Nodes
    for (final node in nodes) {
      final pos = positions[node.id];
      if (pos == null) continue;
      final isRoot = node.type == 'target';
      final isSelected = node.id == selectedNodeId;
      final radius = isRoot ? 21.0 : 14.0;

      Color nodeColor = palette.surfaceElevated;
      Color strokeColor = palette.borderStrong;
      if (isRoot) {
        nodeColor = PanoptesColors.crimson;
        strokeColor = Colors.white;
      } else if (node.type == 'face') {
        nodeColor = PanoptesColors.burgundyDeep;
        strokeColor = PanoptesColors.crimsonBright;
      } else if (node.type == 'pivot') {
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

      final label = node.label.length > 13 ? '${node.label.substring(0, 11)}..' : node.label;
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: isRoot ? 10 : 9,
            fontWeight: isRoot || isSelected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy + radius + 3));
    }
  }

  @override
  bool shouldRepaint(covariant _OsintGraphPainter oldDelegate) {
    return oldDelegate.nodes != nodes ||
        oldDelegate.selectedNodeId != selectedNodeId ||
        oldDelegate.palette.isDark != palette.isDark;
  }
}
