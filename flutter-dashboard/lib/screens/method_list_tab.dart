// lib/screens/method_list_tab.dart
// 메서드 목록 탭: Flame Graph에서 추출한 메서드별 CPU 샘플 수 / 자기 시간 / 비율 테이블 표시

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/profiler_provider.dart';
import '../models/profiler_models.dart';

// 메서드 목록 탭 (StatefulWidget: 정렬 상태 관리)
class MethodListTab extends StatefulWidget {
  const MethodListTab({super.key});

  @override
  State<MethodListTab> createState() => _MethodListTabState();
}

class _MethodListTabState extends State<MethodListTab> {
  // 현재 정렬 기준 컬럼 인덱스 (0: 메서드명, 1: 총 샘플, 2: 자기 시간)
  int _sortColumnIndex = 1;
  // 오름차순 여부 (false = 내림차순)
  bool _sortAscending = false;

  // Flame Graph 트리를 순회하여 메서드별 집계 Row 목록 생성
  List<_MethodRow> _buildRows(FlameNode? root) {
    if (root == null) return [];
    final map = <String, _MethodRow>{};
    // 루트부터 재귀 순회하며 메서드별 샘플 수 집계
    _collect(root, map, root.value);
    return map.values.toList();
  }

  // 트리를 재귀 순회하며 메서드별 데이터 누적 집계
  void _collect(FlameNode node, Map<String, _MethodRow> map, int total) {
    // 루트 노드 자체는 집계에서 제외
    if (node.name != 'root') {
      map.update(
        node.name,
        // 이미 등록된 메서드면 샘플 수와 자기 시간을 누적
        (r) => _MethodRow(
          name: r.name,
          totalSamples: r.totalSamples + node.value,
          selfSamples: r.selfSamples + node.selfTimeMs,
          totalPct: (r.totalSamples + node.value) / total * 100,
        ),
        // 처음 등장하는 메서드면 새 Row 생성
        ifAbsent: () => _MethodRow(
          name: node.name,
          totalSamples: node.value,
          selfSamples: node.selfTimeMs,
          totalPct: node.value / total * 100,
        ),
      );
    }
    // 자식 노드들에 대해 재귀 호출
    for (final c in node.children) { _collect(c, map, total); }
  }

  @override
  Widget build(BuildContext context) {
    // Provider에서 최신 Flame Graph 루트 노드 조회
    final root = context.watch<ProfilerProvider>().latestFlameNode;
    // 메서드별 집계 Row 목록 생성
    var rows = _buildRows(root);

    // 선택된 컬럼과 방향에 따라 정렬
    rows.sort((a, b) {
      final cmp = _sortColumnIndex == 0
          ? a.name.compareTo(b.name)           // 메서드명 알파벳 정렬
          : _sortColumnIndex == 1
              ? a.totalSamples.compareTo(b.totalSamples) // 총 샘플 수 정렬
              : a.selfSamples.compareTo(b.selfSamples);  // 자기 시간 정렬
      // 오름차순/내림차순 적용
      return _sortAscending ? cmp : -cmp;
    });

    // 데이터 없으면 안내 메시지 표시
    if (rows.isEmpty) {
      return Center(
        child: Text('Method 데이터 없음\nCPU 프로파일링을 시작하세요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.38))),
      );
    }

    return SingleChildScrollView(
      child: DataTable(
        // 현재 정렬 기준 컬럼과 방향
        sortColumnIndex: _sortColumnIndex,
        sortAscending: _sortAscending,
        // 컬럼 간 간격
        columnSpacing: 20,
        // 헤더 행 배경색
        headingRowColor: WidgetStateProperty.all(const Color(0xFF0F3460)),
        columns: [
          // 메서드명 컬럼 (클릭 시 알파벳 정렬)
          DataColumn(
            label: Text('Method', style: TextStyle(color: Colors.white.withOpacity(0.7))),
            onSort: (i, asc) => setState(() { _sortColumnIndex = i; _sortAscending = asc; }),
          ),
          // 총 샘플 수 컬럼 (숫자 오른쪽 정렬, 클릭 시 정렬)
          DataColumn(
            label: Text('Total Samples', style: TextStyle(color: Colors.white.withOpacity(0.7))),
            numeric: true,
            onSort: (i, asc) => setState(() { _sortColumnIndex = i; _sortAscending = asc; }),
          ),
          // 자기 시간 컬럼 (ms, 클릭 시 정렬)
          DataColumn(
            label: Text('Self Time(ms)', style: TextStyle(color: Colors.white.withOpacity(0.7))),
            numeric: true,
            onSort: (i, asc) => setState(() { _sortColumnIndex = i; _sortAscending = asc; }),
          ),
          // 전체 대비 비율 컬럼
          DataColumn(
            label: Text('% Total', style: TextStyle(color: Colors.white.withOpacity(0.7))),
            numeric: true,
          ),
        ],
        // 데이터 행 생성
        rows: rows.map((r) => DataRow(cells: [
          // 메서드명 셀: 툴팁으로 전체 이름 표시, 줄임 처리
          DataCell(Tooltip(
            message: r.name, // 전체 이름을 툴팁으로
            child: Text(r.shortName,
                style: TextStyle(fontSize: 12, color: Colors.white, fontFamily: 'monospace'),
                overflow: TextOverflow.ellipsis),
          )),
          // 총 샘플 수 셀 (파란색)
          DataCell(Text('${r.totalSamples}',
              style: TextStyle(color: Colors.blueAccent))),
          // 자기 시간 셀 (1000ms 초과 시 빨간색)
          DataCell(Text('${r.selfSamples}ms',
              style: TextStyle(
                  color: r.selfSamples > 1000 ? Colors.redAccent : Colors.white.withOpacity(0.7)))),
          // 비율 셀 (50% 초과: 빨강, 20% 초과: 주황, 그 외: 흰색)
          DataCell(Text('${r.totalPct.toStringAsFixed(1)}%',
              style: TextStyle(
                  color: r.totalPct > 50
                      ? Colors.redAccent
                      : r.totalPct > 20
                          ? Colors.orangeAccent
                          : Colors.white.withOpacity(0.7)))),
        ])).toList(),
      ),
    );
  }
}

// 메서드 집계 데이터를 담는 내부 클래스
class _MethodRow {
  // 메서드 전체 이름 (패키지 포함)
  final String name;
  // 해당 메서드에서 수집된 총 샘플 수
  final int totalSamples;
  // 해당 메서드 자체(자식 제외) 소비 시간 (ms)
  final int selfSamples;
  // 전체 샘플 대비 비율 (%)
  final double totalPct;

  _MethodRow({required this.name, required this.totalSamples,
      required this.selfSamples, required this.totalPct});

  // 표시용 짧은 이름: '클래스.메서드' 형태
  String get shortName {
    final parts = name.split('.');
    return parts.length > 2 ? '${parts[parts.length - 2]}.${parts.last}' : name;
  }
}
