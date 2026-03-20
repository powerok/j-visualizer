// lib/screens/dashboard_tab.dart
// JVM 메트릭 대시보드 탭: 실시간 Heap/스레드/GC 차트와 요약 카드 표시

import 'package:flutter/material.dart';
// fl_chart: Flutter용 차트 라이브러리 (라인/파이/바 차트 지원)
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../providers/profiler_provider.dart';
import '../models/profiler_models.dart';

// 대시보드 탭 위젯 (StatelessWidget: Provider에서 데이터를 읽어 렌더링)
class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Provider에서 앱 상태 구독 (변경 시 자동 리빌드)
    final provider = context.watch<ProfilerProvider>();
    // 최신 JVM 메트릭 (null이면 아직 수신 전)
    final m = provider.latestMetrics;

    return SingleChildScrollView(
      // 전체 여백
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 상단 요약 카드 행 ───────────────────────────────────
          Row(
            children: [
              // Heap 사용률 요약 카드
              _SummaryCard(
                title: 'Heap Usage',
                // 데이터 있으면 퍼센트, 없으면 '--'
                value: m != null ? '${m.heapUsedPercent.toStringAsFixed(1)}%' : '--',
                // 사용량/최대 MB 표시, 없으면 'Waiting...'
                subtitle: m != null
                    ? '${m.heapUsedMb.toStringAsFixed(0)}MB / ${m.heapMaxMb.toStringAsFixed(0)}MB'
                    : 'Waiting...',
                icon: Icons.memory,
                // 사용률에 따라 색상 변경 (85% 초과: 빨강, 65% 초과: 주황, 그외: 초록)
                color: _heapColor(m?.heapUsedPercent ?? 0),
              ),
              SizedBox(width: 12),
              // 스레드 요약 카드
              _SummaryCard(
                title: 'Threads',
                value: m?.threadCount.toString() ?? '--',
                // Run/Wait/Block 상태별 스레드 수 표시
                subtitle: m != null
                    ? 'Run:${m.runningCount} Wait:${m.waitingCount} Block:${m.blockedCount}'
                    : 'Waiting...',
                icon: Icons.linear_scale,
                color: Colors.blueAccent,
              ),
              SizedBox(width: 12),
              // GC 횟수 요약 카드
              _SummaryCard(
                title: 'GC Collections',
                value: m?.gcInfo.collectionCount.toString() ?? '--',
                // GC 누적 시간과 마지막 GC 원인 표시
                subtitle: m != null
                    ? '${m.gcInfo.collectionTimeMs}ms total · ${m.gcInfo.lastGcCause}'
                    : 'Waiting...',
                icon: Icons.recycling,
                color: Colors.purpleAccent,
              ),
              SizedBox(width: 12),
              // 데드락 감지 요약 카드
              _SummaryCard(
                title: 'Deadlocks',
                value: m?.deadlockCount.toString() ?? '0',
                // 데드락 감지 시 경고 메시지, 없으면 'Normal'
                subtitle: m != null && m.deadlockCount > 0
                    ? '⚠️ Deadlock 감지!'
                    : 'Normal',
                icon: Icons.lock_outline,
                // 데드락 있으면 빨강, 없으면 초록
                color: (m?.deadlockCount ?? 0) > 0
                    ? Colors.redAccent
                    : Colors.greenAccent,
              ),
            ],
          ),
          SizedBox(height: 20),

          // ── Heap 사용률 라인 차트 ─────────────────────────────
          _ChartCard(
            title: 'Heap Usage (%)',
            child: _LineChart(
              // Provider에서 Heap 사용률 히스토리 데이터 전달
              data: provider.heapHistory,
              color: Colors.orangeAccent,
              maxY: 100, // Y축 최대값: 100%
            ),
          ),
          SizedBox(height: 16),

          // ── 스레드 수 라인 차트 ───────────────────────────────
          _ChartCard(
            title: 'Thread Count',
            child: _LineChart(
              data: provider.threadCountHistory,
              color: Colors.blueAccent,
              maxY: 200, // Y축 최대값: 200개
            ),
          ),
          SizedBox(height: 16),

          // ── 스레드 상태 파이 차트 + 메모리 바 차트 (데이터 있을 때만 표시) ─
          if (m != null)
            Row(
              children: [
                // 스레드 상태 분포 파이 차트
                Expanded(
                  child: _ChartCard(
                    title: 'Thread States',
                    height: 200,
                    child: _ThreadPieChart(metrics: m),
                  ),
                ),
                SizedBox(width: 12),
                // 메모리 사용량 바 차트
                Expanded(
                  child: _ChartCard(
                    title: 'Memory Breakdown',
                    height: 200,
                    child: _MemoryBarChart(metrics: m),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // Heap 사용률에 따라 색상 반환하는 헬퍼 메서드
  Color _heapColor(double pct) {
    if (pct > 85) return Colors.redAccent;    // 위험: 빨간색
    if (pct > 65) return Colors.orangeAccent; // 주의: 주황색
    return Colors.greenAccent;               // 정상: 초록색
  }
}

// ── 요약 카드 위젯 ──────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String title, value, subtitle;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title, required this.value,
    required this.subtitle, required this.icon, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Expanded로 감싸 Row 내에서 균등 너비 분배
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          // 카드 배경색
          color: Theme.of(context).cardColor,
          // 둥근 모서리
          borderRadius: BorderRadius.circular(10),
          // 강조색 기반 테두리
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 아이콘 + 제목 행
            Row(children: [
              Icon(icon, color: color, size: 18),
              SizedBox(width: 6),
              Text(title,
                  style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.6))),
            ]),
            SizedBox(height: 8),
            // 핵심 값 (큰 글씨, 강조색)
            Text(value,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
            SizedBox(height: 4),
            // 부가 설명 (작은 글씨, 흘림 처리)
            Text(subtitle,
                style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.38)),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

// ── 차트 카드 래퍼 위젯 ─────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  // 차트 영역 높이 (기본 180px)
  final double height;

  const _ChartCard({required this.title, required this.child, this.height = 180});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 차트 제목
          Text(title,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.7))),
          SizedBox(height: 12),
          // 차트 위젯을 고정 높이로 렌더링
          SizedBox(height: height, child: child),
        ],
      ),
    );
  }
}

// ── 라인 차트 위젯 ──────────────────────────────────────────────────

class _LineChart extends StatelessWidget {
  // Y축 데이터 포인트 목록
  final List<double> data;
  // 라인 색상
  final Color color;
  // Y축 최대값
  final double maxY;

  const _LineChart({required this.data, required this.color, required this.maxY});

  @override
  Widget build(BuildContext context) {
    // 데이터 없으면 대기 메시지 표시
    if (data.isEmpty) {
      return Center(
          child: Text('데이터 대기 중...', style: TextStyle(color: Colors.white.withOpacity(0.38))));
    }
    // 인덱스를 X축, 값을 Y축으로 FlSpot 리스트 생성
    final spots = data.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        // 그리드 설정: 수평선만 표시
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false, // 수직 그리드선 숨김
          getDrawingHorizontalLine: (_) =>
              FlLine(color: Colors.white.withOpacity(0.1), strokeWidth: 1),
        ),
        // 차트 테두리 숨김
        borderData: FlBorderData(show: false),
        // 축 레이블 설정
        titlesData: FlTitlesData(
          // 왼쪽 Y축: 값 레이블 표시
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (v, _) => Text('${v.toInt()}',
                  style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.38))),
            ),
          ),
          // 나머지 축 레이블 숨김
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        // 라인 차트 데이터
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,  // 부드러운 곡선
            color: color,
            barWidth: 2,
            dotData: FlDotData(show: false), // 데이터 포인트 점 숨김
            // 라인 아래 영역 반투명 채움
            belowBarData: BarAreaData(show: true, color: color.withOpacity(0.1)),
          ),
        ],
      ),
    );
  }
}

// ── 스레드 상태 파이 차트 위젯 ────────────────────────────────────────

class _ThreadPieChart extends StatelessWidget {
  final JvmMetrics metrics;
  const _ThreadPieChart({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return PieChart(PieChartData(
      sections: [
        // RUNNABLE 상태: 초록색
        PieChartSectionData(
            value: metrics.runningCount.toDouble(),
            color: Colors.greenAccent,
            title: 'Run\n${metrics.runningCount}',
            radius: 60, titleStyle: _style),
        // WAITING 상태: 파란색
        PieChartSectionData(
            value: metrics.waitingCount.toDouble(),
            color: Colors.blueAccent,
            title: 'Wait\n${metrics.waitingCount}',
            radius: 60, titleStyle: _style),
        // BLOCKED 상태: 주황색
        PieChartSectionData(
            value: metrics.blockedCount.toDouble(),
            color: Colors.orangeAccent,
            title: 'Block\n${metrics.blockedCount}',
            radius: 60, titleStyle: _style),
      ],
      // 섹션 간 간격 (픽셀)
      sectionsSpace: 2,
    ));
  }

  // 파이 차트 레이블 텍스트 스타일
  TextStyle get _style => TextStyle(fontSize: 10, fontWeight: FontWeight.bold);
}

// ── 메모리 사용량 바 차트 위젯 ────────────────────────────────────────

class _MemoryBarChart extends StatelessWidget {
  final JvmMetrics metrics;
  const _MemoryBarChart({required this.metrics});

  @override
  Widget build(BuildContext context) {
    // MB 단위로 변환
    final heapUsed = metrics.heapUsedMb;
    final heapFree = metrics.heapMaxMb - heapUsed;
    final nonHeap = metrics.nonHeapUsed / (1024 * 1024);

    return BarChart(BarChartData(
      barGroups: [
        // Heap 사용량 바 (주황색)
        _bar(0, heapUsed, Colors.orangeAccent),
        // Heap 여유 공간 바 (회색)
        _bar(1, heapFree, Colors.blueGrey),
        // Non-Heap 사용량 바 (보라색)
        _bar(2, nonHeap, Colors.purpleAccent),
      ],
      titlesData: FlTitlesData(
        // 하단 X축: 각 바의 레이블 표시
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (v, _) {
              final labels = ['Heap Used', 'Heap Free', 'Non-Heap'];
              return Text(labels[v.toInt()],
                  style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.38)));
            },
          ),
        ),
        // 왼쪽 Y축: MB 단위 레이블
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true, reservedSize: 40,
            getTitlesWidget: (v, _) => Text('${v.toInt()}MB',
                style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.38))),
          ),
        ),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      // 수직 그리드선 숨김
      gridData: FlGridData(drawVerticalLine: false),
      borderData: FlBorderData(show: false),
    ));
  }

  // 바 차트 그룹 생성 헬퍼 메서드
  BarChartGroupData _bar(int x, double y, Color color) =>
      BarChartGroupData(x: x, barRods: [
        BarChartRodData(
            toY: y,        // 바 높이 (MB)
            color: color,
            width: 30,     // 바 너비
            borderRadius: BorderRadius.circular(4)) // 둥근 상단
      ]);
}
