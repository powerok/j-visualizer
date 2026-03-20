// lib/screens/call_tree_tab.dart
// Call Tree 탭: CPU 프로파일 데이터를 계층적 트리 형태로 표시하고 메서드별 샘플 비율 시각화

// JSON 인코딩/디코딩 라이브러리
import 'dart:convert';
import 'package:flutter/material.dart';
// HTTP 요청 패키지 (프로파일 히스토리 조회용)
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
// 날짜 포맷팅 패키지
import 'package:intl/intl.dart';
import '../providers/profiler_provider.dart';
import '../models/profiler_models.dart';
// Call Tree 탭 위젯 (StatefulWidget: 하이라이트, 히스토리 선택 상태 관리)
  class CallTreeTab extends StatefulWidget {
  const CallTreeTab({super.key});

  @override
  State<CallTreeTab> createState() => _CallTreeTabState();
}

class _CallTreeTabState extends State<CallTreeTab> {
  // 강조 표시할 패키지 접두사 (사용자 지정 가능, 기본: 'com.jvisualizer')
  String _highlight = 'com.jvisualizer';
  // 백엔드에서 불러온 CPU 프로파일 히스토리 목록
  List<Map<String, dynamic>> _history = [];
  // 선택된 프로파일 ID (null이면 실시간 LIVE 데이터 표시)
  String? _selectedProfileId;
  // 선택된 히스토리 프로파일의 루트 FlameNode
  FlameNode? _historicalRoot;

  @override
  // 위젯 초기화 시 프로파일 히스토리 자동 로드
  void initState() {
    super.initState();
    _loadHistory();
  }

  // 백엔드 /api/profile/history에서 프로파일 히스토리 목록 조회
  Future<void> _loadHistory() async {
    try {
      final url = context.read<ProfilerProvider>().serverUrl;
      final res = await http.get(Uri.parse('$url/api/profile/history'));
      if (res.statusCode == 200) {
        setState(() => _history = (jsonDecode(res.body) as List).cast());
      }
    } catch (_) {}
  }

  // 특정 프로파일 ID를 선택하여 히스토리 데이터를 FlameNode 트리로 변환
  Future<void> _selectProfile(String id) async {
    try {
      final url = context.read<ProfilerProvider>().serverUrl;
      final res = await http.get(Uri.parse('$url/api/profile/history'));
      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
        final p = list.firstWhere((e) => e['id'] == id, orElse: () => {});
        if (p.isNotEmpty) {
          final jsonStr = p['flameGraphJson'] ?? p['flame_graph_json'];
          if (jsonStr != null) {
            setState(() {
              _selectedProfileId = id;
              _historicalRoot = FlameNode.fromJson(jsonDecode(jsonStr.toString()));
            });
          }
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // Provider에서 실시간 최신 FlameNode 조회
  final liveRoot = context.watch<ProfilerProvider>().latestFlameNode;
    // 선택 프로파일 ID 있으면 히스토리 사용, 없으면 실시간 데이터 사용
  final root = _selectedProfileId != null ? _historicalRoot : liveRoot;

    return Column(
      children: [
        // 상단 툴바: 히스토리 선택, 새로고침, 하이라이트 입력, 범례
  // ── 툴바 ────────────────────────────────────────────────
        Container(
          color: Theme.of(context).cardColor,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(children: [
            Icon(Icons.account_tree, color: Colors.blueAccent, size: 16),
            SizedBox(width: 6),

            // 실시간 / 히스토리 프로파일 선택 드롭다운
  // 히스토리 드롭다운
            _HistoryDropdown(
              history: _history,
              selectedId: _selectedProfileId,
              onChanged: (id) {
                if (id == null) {
                  setState(() { _selectedProfileId = null; _historicalRoot = null; });
                } else {
                  _selectProfile(id);
                }
              },
            ),

            SizedBox(width: 6),
            IconButton(icon: Icon(Icons.refresh, size: 16), onPressed: _loadHistory,
                tooltip: '새로고침', color: Colors.white.withOpacity(0.6),
                padding: EdgeInsets.zero, constraints: BoxConstraints()),

            SizedBox(width: 12),
            Text('Highlight:', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.6))),
            SizedBox(width: 6),
            SizedBox(
              width: 180,
              child: TextField(
                controller: TextEditingController(text: _highlight),
                style: TextStyle(fontSize: 12, color: Colors.white),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                  hintText: 'com.jvisualizer',
                  hintStyle: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.24)),
                ),
                // 엔터 입력 시 하이라이트 텍스트 업데이트 (앞뒤 공백 제거)
  onSubmitted: (v) => setState(() => _highlight = v.trim()),
              ),
            ),
            SizedBox(width: 10),
            _Legend(color: Colors.orangeAccent, label: 'Your code'),
            SizedBox(width: 8),
            _Legend(color: Colors.white.withOpacity(0.38), label: 'Framework/JVM'),
            Spacer(),
            if (root != null)
              Text('Samples: ${root.value}',
                  style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.38))),
          ]),
        ),
        Divider(height: 1),

        // 트리 뷰 영역: 데이터 없으면 안내 메시지, 있으면 트리 렌더링
  // ── 트리 ─────────────────────────────────────────────────
        Expanded(
          child: root == null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.account_tree, size: 48, color: Colors.white.withOpacity(0.12)),
                    SizedBox(height: 12),
                    Text('CPU 프로파일링 데이터 없음\nAgent 연결 후 대기하세요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withOpacity(0.38), fontSize: 13)),
                  ]),
                )
              : _ScrollableTree(
                  child: _CallTreeNode(
                      node: root, depth: 0,
                      totalSamples: root.value, highlight: _highlight),
                ),
        ),
      ],
    );
  }
}

// ── 공통 히스토리 드롭다운 ────────────────────────────────────────

// ── 양방향 스크롤 래퍼 ─────────────────────────────────────────

// 수평·수직 양방향 스크롤을 지원하는 트리 래퍼 위젯
  class _ScrollableTree extends StatefulWidget {
  final Widget child;
  const _ScrollableTree({required this.child});

  @override
  State<_ScrollableTree> createState() => _ScrollableTreeState();
}

class _ScrollableTreeState extends State<_ScrollableTree> {
  // 수직 스크롤 컨트롤러
  final _verticalController = ScrollController();
  // 수평 스크롤 컨트롤러
  final _horizontalController = ScrollController();

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _verticalController,
      thumbVisibility: true,
      child: Scrollbar(
        controller: _horizontalController,
        thumbVisibility: true,
        notificationPredicate: (n) => n.depth == 1,
        child: SingleChildScrollView(
          controller: _verticalController,
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 16, 32, 32),
            child: IntrinsicWidth(
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

// 프로파일 히스토리 선택 드롭다운 위젯
  class _HistoryDropdown extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  const _HistoryDropdown({
    required this.history, required this.selectedId, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: selectedId,
          isDense: true,
          dropdownColor: const Color(0xFF16213E),
          style: const TextStyle(fontSize: 12, color: Colors.white),
          hint: _liveChip(),
          items: [
            DropdownMenuItem<String?>(value: null, child: _liveChip()),
            ...history.map((p) {
              final ts = p['timestamp']?.toString() ?? '';
              String t = ts;
              try { t = DateFormat('MM-dd HH:mm:ss').format(DateTime.parse(ts).toLocal()); } catch (_) {}
              final s = p['totalSamples'] ?? p['total_samples'] ?? 0;
              return DropdownMenuItem<String?>(
                value: p['id']?.toString(),
                child: Text('$t  ($s samples)', style: const TextStyle(fontSize: 12)),
              );
            }),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _liveChip() => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 8, height: 8,
        decoration: BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
    SizedBox(width: 6),
    Text('LIVE', style: TextStyle(fontSize: 12, color: Colors.greenAccent,
        fontWeight: FontWeight.bold)),
  ]);
}

// 색상 범례 위젯 (Your code / Framework·JVM 구분)
  class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 10, height: 10,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
    SizedBox(width: 4),
    Text(label, style: TextStyle(fontSize: 11, color: color)),
  ]);
}

// ── Call Tree Node ───────────────────────────────────────────────

// 개별 호출 트리 노드 위젯 (접힘/펼침 상태 관리)
  class _CallTreeNode extends StatefulWidget {
  final FlameNode node;
  final int depth, totalSamples;
  final String highlight;

  const _CallTreeNode({
    required this.node, required this.depth,
    required this.totalSamples, required this.highlight,
  });

  @override
  State<_CallTreeNode> createState() => _CallTreeNodeState();
}

class _CallTreeNodeState extends State<_CallTreeNode> {
  // 현재 노드의 자식 펼침 여부
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    // 앱 코드(하이라이트 대상)이거나 루트 노드면 기본 펼침, 그 외 닫힘
  // 앱 코드이거나 root이면 자동 펼침, 나머지는 닫힘
    final name = widget.node.name;
    _expanded = name == 'root' ||
        (widget.highlight.isNotEmpty && name.startsWith(widget.highlight));
  }

  @override
  Widget build(BuildContext context) {
    // 전체 샘플 대비 현재 노드 샘플 비율 계산 (퍼센트)
  final pct = widget.totalSamples > 0
        ? widget.node.value / widget.totalSamples * 100 : 0.0;
    final hasChildren = widget.node.children.isNotEmpty;

    // 하이라이트 패키지 접두사와 노드 이름 비교하여 강조 여부 결정
  final isHighlighted = widget.highlight.isNotEmpty &&
        widget.node.name.startsWith(widget.highlight);
    final nameColor = isHighlighted ? Colors.orangeAccent : Colors.white.withOpacity(0.54);
    final barColor = isHighlighted
        ? (pct > 50 ? Colors.redAccent : Colors.orangeAccent)
        : Colors.blueGrey;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      InkWell(
        onTap: null,
        child: Container(
          color: isHighlighted ? Colors.orangeAccent.withOpacity(0.06) : Colors.transparent,
          padding: EdgeInsets.only(left: widget.depth * 16.0, top: 2, bottom: 2),
          child: Row(children: [
            SizedBox(
              width: 20,
              child: hasChildren
                  ? GestureDetector(
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Container(
                        width: 14, height: 14,
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: isHighlighted
                                  ? Colors.orangeAccent.withOpacity(0.6)
                                  : Colors.white.withOpacity(0.25),
                              width: 1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Icon(
                          _expanded ? Icons.remove : Icons.add,
                          size: 10,
                          color: isHighlighted
                              ? Colors.orangeAccent
                              : Colors.white.withOpacity(0.4),
                        ),
                      ),
                    )
                  : SizedBox(width: 14),
            ),
            SizedBox(width: 2),
            SizedBox(width: 50, height: 5,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: (pct / 100).clamp(0.0, 1.0),
                    backgroundColor: Colors.white.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  ),
                )),
            SizedBox(width: 6),
            SizedBox(width: 42,
                child: Text('${pct.toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 10,
                        color: isHighlighted ? barColor : Colors.white.withOpacity(0.3),
                        fontFamily: 'monospace'),
                    textAlign: TextAlign.right)),
            SizedBox(width: 6),
            if (isHighlighted)
              Container(width: 3, height: 14, margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(color: Colors.orangeAccent,
                      borderRadius: BorderRadius.circular(2))),
            Tooltip(
              message: widget.node.name,
              child: Text(
                isHighlighted ? widget.node.shortName : _shortName(widget.node.name),
                style: TextStyle(
                  fontSize: isHighlighted ? 12 : 11,
                  color: nameColor,
                  fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            SizedBox(width: 8),
            Text('${widget.node.value}',
                style: TextStyle(fontSize: 10,
                    color: isHighlighted ? Colors.white.withOpacity(0.6) : Colors.white.withOpacity(0.2))),
            SizedBox(width: 16),
          ]),
        ),
      ),
      if (_expanded)
        ...widget.node.children.map((c) => _CallTreeNode(
            node: c, depth: widget.depth + 1,
            totalSamples: widget.totalSamples, highlight: widget.highlight)),
    ]);
  }

  // 전체 메서드명에서 "클래스.메서드" 형태의 짧은 이름 반환
  String _shortName(String name) {
    final parts = name.split('.');
    return parts.length >= 2 ? '${parts[parts.length - 2]}.${parts.last}' : name;
  }
}