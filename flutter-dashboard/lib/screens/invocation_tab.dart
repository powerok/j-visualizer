// lib/screens/invocation_tab.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/profiler_provider.dart';

class InvocationTab extends StatefulWidget {
  const InvocationTab({super.key});

  @override
  State<InvocationTab> createState() => _InvocationTabState();
}

class _InvocationTabState extends State<InvocationTab> {
  List<Map<String, dynamic>> _records = [];
  Map<String, dynamic>? _selected;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final url = context.read<ProfilerProvider>().serverUrl;
      final res = await http.get(Uri.parse('$url/api/invocations'));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        setState(() {
          _records = list.cast<Map<String, dynamic>>();
        });
      }
    } catch (e) {
      // ignore
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _clear() async {
    final url = context.read<ProfilerProvider>().serverUrl;
    await http.delete(Uri.parse('$url/api/invocations'));
    setState(() { _records = []; _selected = null; });
  }

  @override
  Widget build(BuildContext context) {
    // 실시간 업데이트 감지
    context.watch<ProfilerProvider>();

    return Row(
      children: [
        // ── 왼쪽: 요청 목록 ──────────────────────────────────
        SizedBox(
          width: 360,
          child: Column(
            children: [
              // 툴바
              Container(
                color: Theme.of(context).cardColor,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(children: [
                  Icon(Icons.timeline, color: Colors.blueAccent, size: 16),
                  SizedBox(width: 8),
                  Text('${_records.length}건',
                      style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.refresh, size: 16),
                    onPressed: _load,
                    tooltip: '새로고침',
                    color: Colors.white.withOpacity(0.6),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, size: 16),
                    onPressed: _clear,
                    tooltip: '전체 삭제',
                    color: Colors.white.withOpacity(0.6),
                  ),
                ]),
              ),
              Divider(height: 1),

              // 목록
              Expanded(
                child: _loading
                    ? Center(child: CircularProgressIndicator())
                    : _records.isEmpty
                        ? Center(
                            child: Text(
                              'HTTP 요청 기록 없음\n/test/* 엔드포인트를 호출하세요.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white.withOpacity(0.38), fontSize: 13),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _records.length,
                            itemBuilder: (ctx, i) {
                              final r = _records[i];
                              final isSelected = _selected?['id'] == r['id'];
                              return _RecordTile(
                                record: r,
                                isSelected: isSelected,
                                onTap: () => setState(() => _selected = r),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),

        VerticalDivider(width: 1),

        // ── 오른쪽: 호출 트리 상세 ────────────────────────────
        Expanded(
          child: _selected == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.account_tree, size: 48, color: Colors.white.withOpacity(0.12)),
                      SizedBox(height: 12),
                      Text('왼쪽 목록에서 요청을 선택하세요',
                          style: TextStyle(color: Colors.white.withOpacity(0.38))),
                    ],
                  ),
                )
              : _InvocationDetail(record: _selected!),
        ),
      ],
    );
  }
}

// ── 목록 타일 ──────────────────────────────────────────────────

class _RecordTile extends StatelessWidget {
  final Map<String, dynamic> record;
  final bool isSelected;
  final VoidCallback onTap;

  const _RecordTile({
    required this.record,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final elapsed = record['elapsedMs'] ?? record['elapsed_ms'] ?? 0;
    final endpoint = record['endpoint'] ?? '';
    final status = record['httpStatus'] ?? record['http_status'] ?? 200;
    final ts = record['timestamp'];
    String timeStr = '';
    if (ts != null) {
      try {
        final dt = DateTime.parse(ts.toString());
        timeStr = DateFormat('HH:mm:ss').format(dt.toLocal());
      } catch (_) {}
    }

    final color = elapsed > 500
        ? Colors.redAccent
        : elapsed > 100
            ? Colors.orangeAccent
            : Colors.greenAccent;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        color: isSelected
            ? Colors.blueAccent.withOpacity(0.15)
            : Colors.transparent,
        child: Row(children: [
          Container(
            width: 3, height: 40,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2)),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(endpoint,
                  style: TextStyle(fontSize: 12, color: Colors.white),
                  overflow: TextOverflow.ellipsis),
              SizedBox(height: 3),
              Row(children: [
                Text(timeStr,
                    style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.38))),
                SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: status >= 400
                        ? Colors.red.withOpacity(0.2)
                        : Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text('$status',
                      style: TextStyle(
                          fontSize: 10,
                          color: status >= 400 ? Colors.redAccent : Colors.greenAccent)),
                ),
              ]),
            ]),
          ),
          Text('${elapsed}ms',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ]),
      ),
    );
  }
}

// ── 호출 트리 상세 ──────────────────────────────────────────────

class _InvocationDetail extends StatelessWidget {
  final Map<String, dynamic> record;
  const _InvocationDetail({required this.record});

  @override
  Widget build(BuildContext context) {
    final endpoint = record['endpoint'] ?? '';
    final elapsed = record['elapsedMs'] ?? record['elapsed_ms'] ?? 0;
    final treeJson = record['treeJson'] ?? record['tree_json'] ?? record['tree'];
    final treeText = record['treeText'] ?? record['tree_text'] ?? '';

    Map<String, dynamic>? tree;
    if (treeJson != null && treeJson.toString().isNotEmpty) {
      try {
        final decoded = jsonDecode(treeJson.toString());
        // treeJson이 JSON 문자열로 한 번 더 인코딩된 경우 처리
        if (decoded is Map<String, dynamic>) {
          tree = decoded;
        } else if (decoded is String) {
          tree = jsonDecode(decoded);
        }
      } catch (e) {
        // parse 실패 시 tree = null → treeText fallback
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).cardColor,
          child: Row(children: [
            Icon(Icons.account_tree, color: Colors.blueAccent, size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text(endpoint,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${elapsed}ms',
                  style: TextStyle(
                      color: Colors.blueAccent, fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
        Divider(height: 1),

        // 탭: 트리뷰 / 텍스트뷰
        Expanded(
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                TabBar(
                  tabs: const [
                    Tab(text: '🌳 Call Tree'),
                    Tab(text: '📄 Raw Text'),
                  ],
                  labelColor: Colors.blueAccent,
                  unselectedLabelColor: Colors.white.withOpacity(0.38),
                  indicatorColor: Colors.blueAccent,
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // 트리 뷰
                      tree != null
                          ? SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: _TreeNode(node: tree, depth: 0, rootDuration: elapsed),
                            )
                          : SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: _TextTree(text: treeText, elapsed: elapsed),
                            ),
                      // Raw 텍스트 뷰
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: SelectableText(
                          treeText.isNotEmpty ? treeText : treeJson?.toString() ?? '',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.7), fontFamily: 'monospace',
                              fontSize: 12, height: 1.6),
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
    );
  }
}

// ── treeText fallback 위젯 ────────────────────────────────────

class _TextTree extends StatelessWidget {
  final String text;
  final int elapsed;
  const _TextTree({required this.text, required this.elapsed});

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return Center(
        child: Text('트리 데이터 없음',
            style: TextStyle(color: Colors.white.withOpacity(0.38))),
      );
    }

    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        // 들여쓰기 계산
        int indent = 0;
        for (int i = 0; i < line.length; i++) {
          if (line[i] == ' ') indent++;
          else break;
        }
        final depth = indent ~/ 2;
        final trimmed = line.trim();

        // ms 추출
        final msMatch = RegExp(r'\((\d+)ms').firstMatch(trimmed);
        final ms = msMatch != null ? int.tryParse(msMatch.group(1) ?? '0') ?? 0 : 0;
        final pct = elapsed > 0 ? ms / elapsed * 100 : 0.0;

        final isHighlighted = trimmed.contains('com.jvisualizer') ||
            trimmed.startsWith('→ [HTTP]');
        final nameColor = isHighlighted
            ? Colors.orangeAccent
            : Colors.white.withOpacity(0.54);
        final barColor = isHighlighted
            ? (pct > 50 ? Colors.redAccent : Colors.orangeAccent)
            : Colors.blueGrey;

        return Container(
          color: isHighlighted
              ? Colors.orangeAccent.withOpacity(0.06)
              : Colors.transparent,
          padding: EdgeInsets.only(left: depth * 16.0, top: 2, bottom: 2),
          child: Row(children: [
            SizedBox(width: 16,
                child: Icon(Icons.chevron_right,
                    size: 12,
                    color: Colors.white.withOpacity(0.2))),
            SizedBox(width: 2),
            SizedBox(
              width: 50, height: 5,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: (pct / 100).clamp(0.0, 1.0),
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                ),
              ),
            ),
            SizedBox(width: 6),
            SizedBox(
              width: 42,
              child: Text(
                pct > 0 ? '${pct.toStringAsFixed(1)}%' : '',
                style: TextStyle(
                    fontSize: 10,
                    color: isHighlighted ? barColor : Colors.white.withOpacity(0.3),
                    fontFamily: 'monospace'),
                textAlign: TextAlign.right,
              ),
            ),
            SizedBox(width: 6),
            if (isHighlighted)
              Container(
                width: 3, height: 14,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                    color: Colors.orangeAccent,
                    borderRadius: BorderRadius.circular(2)),
              ),
            Expanded(
              child: Text(
                trimmed,
                style: TextStyle(
                  fontSize: isHighlighted ? 12 : 11,
                  color: nameColor,
                  fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        );
      }).toList(),
    );
  }
}

// ── 트리 노드 위젯 ──────────────────────────────────────────────

const String _kHighlight = 'com.jvisualizer';

class _TreeNode extends StatefulWidget {
  final Map<String, dynamic> node;
  final int depth;
  final int rootDuration;

  const _TreeNode({
    required this.node,
    required this.depth,
    required this.rootDuration,
  });

  @override
  State<_TreeNode> createState() => _TreeNodeState();
}

class _TreeNodeState extends State<_TreeNode> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final name = widget.node['name']?.toString() ?? 'unknown';
    final fullName = widget.node['full_name']?.toString() ?? name;
    final dur = (widget.node['duration_ms'] as num?)?.toInt() ?? 0;
    final children = (widget.node['children'] as List<dynamic>?) ?? [];
    final pct = widget.rootDuration > 0 ? dur / widget.rootDuration * 100 : 0.0;

    final isHighlighted = fullName.startsWith(_kHighlight) ||
        name.startsWith('[HTTP]');
    final nameColor = isHighlighted ? Colors.orangeAccent : Colors.white.withOpacity(0.54);
    final barColor = isHighlighted
        ? (pct > 50 ? Colors.redAccent : Colors.orangeAccent)
        : Colors.blueGrey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: children.isNotEmpty
              ? () => setState(() => _expanded = !_expanded)
              : null,
          child: Container(
            color: isHighlighted
                ? Colors.orangeAccent.withOpacity(0.06)
                : Colors.transparent,
            padding: EdgeInsets.only(
                left: widget.depth * 16.0, top: 2, bottom: 2),
            child: Row(children: [
              SizedBox(
                width: 16,
                child: children.isNotEmpty
                    ? Icon(
                        _expanded ? Icons.expand_more : Icons.chevron_right,
                        size: 13, color: Colors.white.withOpacity(0.3))
                    : null,
              ),
              SizedBox(width: 2),
              SizedBox(
                width: 50,
                height: 5,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: (pct / 100).clamp(0.0, 1.0),
                    backgroundColor: Colors.white.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  ),
                ),
              ),
              SizedBox(width: 6),
              SizedBox(
                width: 42,
                child: Text(
                  '${pct.toStringAsFixed(1)}%',
                  style: TextStyle(
                      fontSize: 10,
                      color: isHighlighted ? barColor : Colors.white.withOpacity(0.3),
                      fontFamily: 'monospace'),
                  textAlign: TextAlign.right,
                ),
              ),
              SizedBox(width: 6),
              if (isHighlighted)
                Container(
                  width: 3, height: 14,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              Expanded(
                child: Tooltip(
                  message: fullName,
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: isHighlighted ? 12 : 11,
                      color: nameColor,
                      fontWeight: isHighlighted
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Text('${dur}ms',
                  style: TextStyle(
                      fontSize: 11,
                      color: isHighlighted ? barColor : Colors.white.withOpacity(0.24),
                      fontWeight: isHighlighted
                          ? FontWeight.w600
                          : FontWeight.normal)),
              SizedBox(width: 8),
            ]),
          ),
        ),
        if (_expanded)
          ...children.map((child) {
            if (child is Map<String, dynamic>) {
              return _TreeNode(
                node: child,
                depth: widget.depth + 1,
                rootDuration: widget.rootDuration,
              );
            }
            return const SizedBox.shrink();
          }),
      ],
    );
  }
}
