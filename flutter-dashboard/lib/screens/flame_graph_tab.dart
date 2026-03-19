// lib/screens/flame_graph_tab.dart
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/profiler_provider.dart';
import '../models/profiler_models.dart';
import 'package:intl/intl.dart';

class FlameGraphTab extends StatefulWidget {
  const FlameGraphTab({super.key});

  @override
  State<FlameGraphTab> createState() => _FlameGraphTabState();
}

class _FlameGraphTabState extends State<FlameGraphTab> {
  FlameNode? _selectedNode;
  List<Map<String, dynamic>> _history = [];
  String? _selectedProfileId; // null = 실시간
  FlameNode? _historicalRoot;
  bool _loadingHistory = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final url = context.read<ProfilerProvider>().serverUrl;
      final res = await http.get(Uri.parse('$url/api/profile/history'));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        setState(() => _history = list.cast<Map<String, dynamic>>());
      }
    } catch (_) {}
    setState(() => _loadingHistory = false);
  }

  Future<void> _selectProfile(String id) async {
    try {
      final url = context.read<ProfilerProvider>().serverUrl;
      final res = await http.get(Uri.parse('$url/api/profile/history'));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        final profile = list.firstWhere((p) => p['id'] == id, orElse: () => null);
        if (profile != null) {
          final jsonStr = profile['flameGraphJson'] ?? profile['flame_graph_json'];
          if (jsonStr != null && jsonStr.toString().isNotEmpty) {
            setState(() {
              _selectedProfileId = id;
              _historicalRoot = FlameNode.fromJson(jsonDecode(jsonStr.toString()));
              _selectedNode = null;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('load profile error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProfilerProvider>();
    final liveRoot = provider.latestFlameNode;
    final root = _selectedProfileId != null ? _historicalRoot : liveRoot;

    return Column(
      children: [
        // ── 툴바 ──────────────────────────────────────────────
        Container(
          color: Theme.of(context).cardColor,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(children: [
            Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 16),
            SizedBox(width: 6),

            // 실시간 / 히스토리 선택 드롭다운
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _selectedProfileId,
                  isDense: true,
                  dropdownColor: const Color(0xFF16213E),
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                  hint: Row(children: [
                    Container(width: 8, height: 8,
                        decoration: BoxDecoration(
                            color: Colors.greenAccent, shape: BoxShape.circle)),
                    SizedBox(width: 6),
                    Text('LIVE', style: TextStyle(fontSize: 12,
                        color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                  ]),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Row(children: [
                        Container(width: 8, height: 8,
                            decoration: BoxDecoration(
                                color: Colors.greenAccent, shape: BoxShape.circle)),
                        SizedBox(width: 6),
                        Text('LIVE', style: TextStyle(fontSize: 12,
                            color: Colors.greenAccent)),
                      ]),
                    ),
                    ..._history.map((p) {
                      final ts = p['timestamp']?.toString() ?? '';
                      String timeStr = ts;
                      try {
                        timeStr = DateFormat('MM-dd HH:mm:ss')
                            .format(DateTime.parse(ts).toLocal());
                      } catch (_) {}
                      final samples = p['totalSamples'] ?? p['total_samples'] ?? 0;
                      return DropdownMenuItem<String?>(
                        value: p['id']?.toString(),
                        child: Text('$timeStr  ($samples samples)',
                            style: const TextStyle(fontSize: 12)),
                      );
                    }),
                  ],
                  onChanged: (id) {
                    if (id == null) {
                      setState(() {
                        _selectedProfileId = null;
                        _historicalRoot = null;
                        _selectedNode = null;
                      });
                    } else {
                      _selectProfile(id);
                    }
                  },
                ),
              ),
            ),

            SizedBox(width: 8),
            // 새로고침
            IconButton(icon: Icon(Icons.refresh, size: 16),
                onPressed: _loadHistory, tooltip: '히스토리 새로고침',
                color: Colors.white.withOpacity(0.6)),

            Spacer(),
            if (root != null)
              Text('Samples: ${root.value}  Depth: ${_calcDepth(root)}',
                  style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.38))),
          ]),
        ),

        // ── Flame Graph Canvas ──────────────────────────────
        Expanded(
          child: root == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_fire_department,
                          size: 48, color: Colors.white.withOpacity(0.12)),
                      SizedBox(height: 16),
                      Text('CPU 프로파일링 데이터가 없습니다.\nAgent를 연결하고 대기하세요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withOpacity(0.38), fontSize: 13)),
                    ],
                  ),
                )
              : Row(
                  children: [
                    Expanded(
                      child: InteractiveViewer(
                        scaleEnabled: true,
                        minScale: 0.3,
                        maxScale: 5.0,
                        child: FlameGraphCanvas(
                          root: root,
                          onNodeTap: (node) => setState(() => _selectedNode = node),
                        ),
                      ),
                    ),
                    if (_selectedNode != null)
                      _NodeDetailPanel(
                        node: _selectedNode!,
                        root: root,
                        onClose: () => setState(() => _selectedNode = null),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  int _calcDepth(FlameNode node, [int depth = 0]) {
    if (node.children.isEmpty) return depth;
    return node.children
        .map((c) => _calcDepth(c, depth + 1))
        .reduce((a, b) => a > b ? a : b);
  }
}

// ── Flame Graph Canvas (기존과 동일) ───────────────────────────

class FlameGraphCanvas extends StatefulWidget {
  final FlameNode root;
  final ValueChanged<FlameNode> onNodeTap;

  const FlameGraphCanvas({super.key, required this.root, required this.onNodeTap});

  @override
  State<FlameGraphCanvas> createState() => _FlameGraphCanvasState();
}

class _FlameGraphCanvasState extends State<FlameGraphCanvas> {
  Offset? _hoverPos;
  final double _rowHeight = 22;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      _layoutNode(widget.root, 0, width, 0);
      final depth = _maxDepth(widget.root);
      final totalHeight = (depth + 1) * _rowHeight;

      return GestureDetector(
        onTapDown: (details) {
          final node = _hitTest(widget.root, details.localPosition);
          if (node != null) widget.onNodeTap(node);
        },
        child: MouseRegion(
          onHover: (e) => setState(() => _hoverPos = e.localPosition),
          onExit: (_) => setState(() => _hoverPos = null),
          child: CustomPaint(
            size: Size(width, totalHeight.clamp(200, 2000)),
            painter: _FlameGraphPainter(
              root: widget.root,
              rowHeight: _rowHeight,
              hoverPos: _hoverPos,
            ),
          ),
        ),
      );
    });
  }

  void _layoutNode(FlameNode node, double x, double width, int depth) {
    node.x = x; node.y = depth * _rowHeight;
    node.width = width; node.depth = depth.toDouble();
    if (node.children.isEmpty || node.value == 0) return;
    double cx = x;
    for (final child in node.children) {
      final childWidth = width * child.value / node.value;
      _layoutNode(child, cx, childWidth, depth + 1);
      cx += childWidth;
    }
  }

  int _maxDepth(FlameNode node, [int d = 0]) {
    if (node.children.isEmpty) return d;
    return node.children.map((c) => _maxDepth(c, d + 1)).reduce((a, b) => a > b ? a : b);
  }

  FlameNode? _hitTest(FlameNode node, Offset pos) {
    if (pos.dx >= node.x && pos.dx <= node.x + node.width &&
        pos.dy >= node.y && pos.dy <= node.y + _rowHeight) return node;
    for (final child in node.children) {
      final hit = _hitTest(child, pos);
      if (hit != null) return hit;
    }
    return null;
  }
}

class _FlameGraphPainter extends CustomPainter {
  final FlameNode root;
  final double rowHeight;
  final Offset? hoverPos;

  static final List<Color> _palette = [
    const Color(0xFFE57373), const Color(0xFF81C784),
    const Color(0xFF64B5F6), const Color(0xFFFFB74D),
    const Color(0xFFBA68C8), const Color(0xFF4DB6AC),
    const Color(0xFFF06292), const Color(0xFFAED581),
  ];

  _FlameGraphPainter({required this.root, required this.rowHeight, this.hoverPos});

  @override
  void paint(Canvas canvas, Size size) { _paintNode(canvas, root, size); }

  void _paintNode(Canvas canvas, FlameNode node, Size size) {
    if (node.width < 2) return;
    final rect = Rect.fromLTWH(node.x + 1, node.y + 1, node.width - 2, rowHeight - 2);
    final isHovered = hoverPos != null && rect.contains(hoverPos!);
    final colorIdx = node.name.hashCode.abs() % _palette.length;
    final baseColor = _palette[colorIdx];
    final fillColor = isHovered ? baseColor : baseColor.withOpacity(0.8);
    final paint = Paint()..color = fillColor;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(2));
    canvas.drawRRect(rrect, paint);
    if (isHovered) {
      canvas.drawRRect(rrect,
          Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);
    }
    if (node.width > 30) {
      final span = TextSpan(
        text: node.shortName,
        style: TextStyle(fontSize: 10,
            color: isHovered ? Colors.white : Colors.white.withOpacity(0.9),
            fontWeight: isHovered ? FontWeight.bold : FontWeight.normal),
      );
      final tp = TextPainter(text: span, textDirection: ui.TextDirection.ltr)
        ..layout(maxWidth: node.width - 6);
      if (tp.width < node.width - 4) {
        tp.paint(canvas, Offset(node.x + 3, node.y + (rowHeight - tp.height) / 2));
      }
    }
    for (final child in node.children) { _paintNode(canvas, child, size); }
  }

  @override
  bool shouldRepaint(_FlameGraphPainter old) =>
      old.root != root || old.hoverPos != hoverPos;
}

class _NodeDetailPanel extends StatelessWidget {
  final FlameNode node, root;
  final VoidCallback onClose;
  const _NodeDetailPanel({required this.node, required this.root, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final pct = root.value > 0 ? node.value / root.value * 100 : 0.0;
    return Container(
      width: 280,
      color: const Color(0xFF0F3460),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Node Detail',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          Spacer(),
          IconButton(icon: Icon(Icons.close, size: 16),
              onPressed: onClose, color: Colors.white.withOpacity(0.6)),
        ]),
        Divider(),
        _row('Method', node.name, isCode: true),
        _row('Samples', '${node.value}'),
        _row('% of Total', '${pct.toStringAsFixed(2)}%'),
        _row('Self Time', '${node.selfTimeMs}ms'),
        _row('Children', '${node.children.length}'),
      ]),
    );
  }

  Widget _row(String label, String value, {bool isCode = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.38))),
      Text(value, style: TextStyle(
          fontSize: isCode ? 11 : 13, color: Colors.white,
          fontFamily: isCode ? 'monospace' : null),
          overflow: TextOverflow.ellipsis, maxLines: 3),
    ]),
  );
}