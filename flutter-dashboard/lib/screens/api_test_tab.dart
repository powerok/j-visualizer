// lib/screens/api_test_tab.dart
// Example-App REST API 테스트 탭: 각 시나리오별 버튼으로 API 호출 및 결과 표시

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/profiler_provider.dart';

// API 테스트 탭 (StatefulWidget: 호출 결과, 로딩 상태 관리)
class ApiTestTab extends StatefulWidget {
  const ApiTestTab({super.key});

  @override
  State<ApiTestTab> createState() => _ApiTestTabState();
}

class _ApiTestTabState extends State<ApiTestTab> {
  // 각 API 카드의 로딩 상태 (key: apiId)
  final Map<String, bool> _loading = {};
  // 각 API 카드의 응답 결과 (key: apiId)
  final Map<String, _ApiResult> _results = {};
  // 선택된 API 결과 상세 표시
  String? _selectedApiId;

  // example-app URL: Provider에서 직접 읽기 (사이드바에서 설정한 값)
  String _exampleAppUrl(BuildContext context) {
    return context.read<ProfilerProvider>().exampleAppUrl;
  }

  // API 정의 목록
  List<_ApiScenario> get _scenarios => [
    _ApiScenario(
      id: 'status',
      title: 'JVM 상태 확인',
      endpoint: '/test/status',
      method: 'GET',
      icon: Icons.monitor_heart,
      color: Colors.greenAccent,
      description: '현재 JVM 메모리, 스레드, PID 등 기본 상태 조회',
      params: [],
    ),
    _ApiScenario(
      id: 'index',
      title: '엔드포인트 목록',
      endpoint: '/test',
      method: 'GET',
      icon: Icons.list_alt,
      color: Colors.blueAccent,
      description: '사용 가능한 모든 테스트 엔드포인트 목록 조회',
      params: [],
    ),
    _ApiScenario(
      id: 'cpu',
      title: 'CPU 집약 작업',
      endpoint: '/test/cpu-intensive',
      method: 'GET',
      icon: Icons.memory,
      color: Colors.orangeAccent,
      description: 'Flame Graph에서 computeLayer1→2→3 호출 계층 확인',
      params: [_ApiParam(key: 'iterations', defaultValue: '1000', hint: '반복 횟수')],
    ),
    _ApiScenario(
      id: 'memory_leak',
      title: '메모리 누수 시뮬레이션',
      endpoint: '/test/memory-leak',
      method: 'GET',
      icon: Icons.leak_add,
      color: Colors.redAccent,
      description: 'Heap 사용량이 점진적으로 증가하는 메모리 누수 유발',
      params: [_ApiParam(key: 'mb', defaultValue: '20', hint: '누수 크기(MB)')],
    ),
    _ApiScenario(
      id: 'memory_release',
      title: '메모리 해제',
      endpoint: '/test/memory-release',
      method: 'GET',
      icon: Icons.cleaning_services,
      color: Colors.tealAccent,
      description: '누수된 메모리 참조 해제 → GC 수거 유도',
      params: [],
    ),
    _ApiScenario(
      id: 'slow_sql',
      title: 'Slow SQL 시뮬레이션',
      endpoint: '/test/slow-sql',
      method: 'GET',
      icon: Icons.storage,
      color: Colors.purpleAccent,
      description: 'N+1 쿼리, LIKE 풀스캔 유발 → SQL 탭에서 확인',
      params: [],
    ),
    _ApiScenario(
      id: 'thread',
      title: 'Thread Contention',
      endpoint: '/test/thread-contention',
      method: 'GET',
      icon: Icons.linear_scale,
      color: Colors.yellowAccent,
      description: '여러 스레드가 동일 락 경쟁 → BLOCKED 스레드 발생',
      params: [_ApiParam(key: 'threads', defaultValue: '10', hint: '스레드 수')],
    ),
    _ApiScenario(
      id: 'deadlock',
      title: 'Deadlock 시뮬레이션',
      endpoint: '/test/deadlock',
      method: 'GET',
      icon: Icons.lock_outline,
      color: Colors.red,
      description: '두 스레드가 서로의 락을 대기 → 데드락 감지 테스트',
      params: [],
    ),
    _ApiScenario(
      id: 'full_load',
      title: '복합 부하 테스트',
      endpoint: '/test/full-load',
      method: 'GET',
      icon: Icons.rocket_launch,
      color: Colors.deepOrangeAccent,
      description: 'CPU + 메모리 + SQL + 스레드 경합 동시 실행',
      params: [],
    ),
  ];

  // API 호출 실행
  Future<void> _call(_ApiScenario scenario, Map<String, String> paramValues) async {
    setState(() => _loading[scenario.id] = true);

    final baseUrl = _exampleAppUrl(context);
    // 쿼리 파라미터 조립
    String url = '$baseUrl${scenario.endpoint}';
    if (scenario.params.isNotEmpty) {
      final query = scenario.params
          .map((p) => '${p.key}=${Uri.encodeComponent(paramValues[p.key] ?? p.defaultValue)}')
          .join('&');
      url = '$url?$query';
    }

    final stopwatch = Stopwatch()..start();
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 30));
      stopwatch.stop();

      // JSON 응답 예쁘게 포맷
      String body = response.body;
      try {
        final decoded = jsonDecode(body);
        body = const JsonEncoder.withIndent('  ').convert(decoded);
      } catch (_) {}

      setState(() {
        _results[scenario.id] = _ApiResult(
          statusCode: response.statusCode,
          body: body,
          elapsedMs: stopwatch.elapsedMilliseconds,
          isSuccess: response.statusCode >= 200 && response.statusCode < 300,
          url: url,
        );
        _selectedApiId = scenario.id;
      });
    } catch (e) {
      stopwatch.stop();
      setState(() {
        _results[scenario.id] = _ApiResult(
          statusCode: 0,
          body: '연결 실패: $e\n\nexample-app URL을 확인하세요.\n현재: $baseUrl',
          elapsedMs: stopwatch.elapsedMilliseconds,
          isSuccess: false,
          url: url,
        );
        _selectedApiId = scenario.id;
      });
    } finally {
      setState(() => _loading[scenario.id] = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedResult = _selectedApiId != null ? _results[_selectedApiId] : null;
    final selectedScenario = _selectedApiId != null
        ? _scenarios.firstWhere((s) => s.id == _selectedApiId, orElse: () => _scenarios.first)
        : null;

    return Row(
      children: [
        // ── 왼쪽: API 카드 목록 (스크롤) ────────────────────────────
        SizedBox(
          width: 380,
          child: Column(
            children: [
              // 헤더
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: Theme.of(context).cardColor,
                child: Row(
                  children: [
                    Icon(Icons.api, color: Colors.blueAccent, size: 16),
                    const SizedBox(width: 8),
                    Text('Example App API 테스트',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withOpacity(0.8))),
                    const Spacer(),
                    // example-app URL 표시
                    Text(
                      _exampleAppUrl(context),
                      style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.38)),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // API 카드 목록
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _scenarios.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final s = _scenarios[i];
                    final result = _results[s.id];
                    final isLoading = _loading[s.id] == true;
                    final isSelected = _selectedApiId == s.id;
                    return _ApiCard(
                      scenario: s,
                      result: result,
                      isLoading: isLoading,
                      isSelected: isSelected,
                      onTap: () => setState(() => _selectedApiId = s.id),
                      onCall: (params) => _call(s, params),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        const VerticalDivider(width: 1),

        // ── 오른쪽: 응답 결과 상세 ──────────────────────────────────
        Expanded(
          child: selectedResult == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.api, size: 48, color: Colors.white.withOpacity(0.1)),
                      const SizedBox(height: 16),
                      Text('왼쪽에서 API를 실행하세요',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.38), fontSize: 14)),
                      const SizedBox(height: 8),
                      Text('결과가 여기에 표시됩니다',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.2), fontSize: 12)),
                    ],
                  ),
                )
              : _ResultPanel(
                  scenario: selectedScenario!,
                  result: selectedResult,
                ),
        ),
      ],
    );
  }
}

// ── API 시나리오 카드 위젯 ───────────────────────────────────────────

class _ApiCard extends StatefulWidget {
  final _ApiScenario scenario;
  final _ApiResult? result;
  final bool isLoading;
  final bool isSelected;
  final VoidCallback onTap;
  final Function(Map<String, String>) onCall;

  const _ApiCard({
    required this.scenario,
    required this.result,
    required this.isLoading,
    required this.isSelected,
    required this.onTap,
    required this.onCall,
  });

  @override
  State<_ApiCard> createState() => _ApiCardState();
}

class _ApiCardState extends State<_ApiCard> {
  // 파라미터 입력 컨트롤러 맵
  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final p in widget.scenario.params)
        p.key: TextEditingController(text: p.defaultValue)
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scenario;
    final result = widget.result;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: widget.isSelected
              ? s.color.withOpacity(0.08)
              : const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: widget.isSelected
                ? s.color.withOpacity(0.5)
                : Colors.white.withOpacity(0.07),
            width: widget.isSelected ? 1.5 : 1,
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 카드 헤더: 아이콘 + 제목 + 상태 배지
            Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: s.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(s.icon, color: s.color, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.title,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: Colors.white)),
                      Text(s.endpoint,
                          style: TextStyle(
                              fontSize: 10,
                              color: s.color.withOpacity(0.7),
                              fontFamily: 'monospace')),
                    ],
                  ),
                ),
                // 응답 상태 배지
                if (result != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: result.isSuccess
                          ? Colors.greenAccent.withOpacity(0.15)
                          : Colors.redAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      result.statusCode == 0 ? 'ERR' : '${result.statusCode}',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: result.isSuccess ? Colors.greenAccent : Colors.redAccent),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // 설명
            Text(s.description,
                style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.45))),

            // 파라미터 입력 필드 (있을 때만)
            if (s.params.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: s.params.map((p) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: TextField(
                      controller: _controllers[p.key],
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: p.hint,
                        labelStyle: TextStyle(fontSize: 11, color: s.color.withOpacity(0.6)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: s.color.withOpacity(0.6)),
                        ),
                      ),
                    ),
                  ),
                )).toList(),
              ),
            ],

            const SizedBox(height: 10),
            // 실행 버튼
            Row(
              children: [
                // 응답 시간 표시
                if (result != null)
                  Text('${result.elapsedMs}ms',
                      style: TextStyle(
                          fontSize: 11,
                          color: result.elapsedMs > 1000
                              ? Colors.redAccent
                              : result.elapsedMs > 300
                                  ? Colors.orangeAccent
                                  : Colors.greenAccent)),
                const Spacer(),
                // 실행 버튼
                SizedBox(
                  height: 32,
                  child: ElevatedButton.icon(
                    onPressed: widget.isLoading
                        ? null
                        : () => widget.onCall({
                              for (final p in s.params)
                                p.key: _controllers[p.key]!.text.trim().isEmpty
                                    ? p.defaultValue
                                    : _controllers[p.key]!.text.trim()
                            }),
                    icon: widget.isLoading
                        ? SizedBox(
                            width: 12, height: 12,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Icon(Icons.play_arrow, size: 14),
                    label: Text(widget.isLoading ? '실행 중...' : '실행',
                        style: const TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.isLoading
                          ? Colors.grey.shade700
                          : s.color.withOpacity(0.25),
                      foregroundColor: s.color,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── 응답 결과 상세 패널 ──────────────────────────────────────────────

class _ResultPanel extends StatelessWidget {
  final _ApiScenario scenario;
  final _ApiResult result;

  const _ResultPanel({required this.scenario, required this.result});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 결과 헤더
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          color: Theme.of(context).cardColor,
          child: Row(
            children: [
              Icon(scenario.icon, color: scenario.color, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(scenario.title,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    Text(result.url,
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withOpacity(0.38),
                            fontFamily: 'monospace'),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              // 상태 코드 배지
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: result.isSuccess
                      ? Colors.greenAccent.withOpacity(0.15)
                      : Colors.redAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: result.isSuccess
                        ? Colors.greenAccent.withOpacity(0.4)
                        : Colors.redAccent.withOpacity(0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      result.isSuccess ? Icons.check_circle_outline : Icons.error_outline,
                      size: 14,
                      color: result.isSuccess ? Colors.greenAccent : Colors.redAccent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      result.statusCode == 0
                          ? 'ERROR'
                          : '${result.statusCode} ${_statusText(result.statusCode)}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: result.isSuccess ? Colors.greenAccent : Colors.redAccent),
                    ),
                    const SizedBox(width: 10),
                    Text('${result.elapsedMs}ms',
                        style: TextStyle(
                            fontSize: 12,
                            color: result.elapsedMs > 1000
                                ? Colors.redAccent
                                : result.elapsedMs > 300
                                    ? Colors.orangeAccent
                                    : Colors.greenAccent)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // JSON 응답 본문 (선택/복사 가능)
        Expanded(
          child: Container(
            color: const Color(0xFF0D1117),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: SelectableText(
                result.body,
                style: TextStyle(
                  fontSize: 12,
                  color: result.isSuccess
                      ? Colors.greenAccent.withOpacity(0.9)
                      : Colors.redAccent.withOpacity(0.9),
                  fontFamily: 'monospace',
                  height: 1.6,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _statusText(int code) {
    switch (code) {
      case 200: return 'OK';
      case 201: return 'Created';
      case 400: return 'Bad Request';
      case 404: return 'Not Found';
      case 500: return 'Internal Server Error';
      default: return '';
    }
  }
}

// ── 데이터 클래스들 ─────────────────────────────────────────────────

class _ApiScenario {
  final String id;
  final String title;
  final String endpoint;
  final String method;
  final IconData icon;
  final Color color;
  final String description;
  final List<_ApiParam> params;

  const _ApiScenario({
    required this.id,
    required this.title,
    required this.endpoint,
    required this.method,
    required this.icon,
    required this.color,
    required this.description,
    required this.params,
  });
}

class _ApiParam {
  final String key;
  final String defaultValue;
  final String hint;

  const _ApiParam({
    required this.key,
    required this.defaultValue,
    required this.hint,
  });
}

class _ApiResult {
  final int statusCode;
  final String body;
  final int elapsedMs;
  final bool isSuccess;
  final String url;

  const _ApiResult({
    required this.statusCode,
    required this.body,
    required this.elapsedMs,
    required this.isSuccess,
    required this.url,
  });
}
