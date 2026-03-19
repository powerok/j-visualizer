// lib/screens/dashboard_tab.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../providers/profiler_provider.dart';
import '../models/profiler_models.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProfilerProvider>();
    final m = provider.latestMetrics;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 상단 요약 카드 ──────────────────────────────────
          Row(
            children: [
              _SummaryCard(
                title: 'Heap Usage',
                value: m != null ? '${m.heapUsedPercent.toStringAsFixed(1)}%' : '--',
                subtitle: m != null
                    ? '${m.heapUsedMb.toStringAsFixed(0)}MB / ${m.heapMaxMb.toStringAsFixed(0)}MB'
                    : 'Waiting...',
                icon: Icons.memory,
                color: _heapColor(m?.heapUsedPercent ?? 0),
              ),
              SizedBox(width: 12),
              _SummaryCard(
                title: 'Threads',
                value: m?.threadCount.toString() ?? '--',
                subtitle: m != null
                    ? 'Run:${m.runningCount} Wait:${m.waitingCount} Block:${m.blockedCount}'
                    : 'Waiting...',
                icon: Icons.linear_scale,
                color: Colors.blueAccent,
              ),
              SizedBox(width: 12),
              _SummaryCard(
                title: 'GC Collections',
                value: m?.gcInfo.collectionCount.toString() ?? '--',
                subtitle: m != null
                    ? '${m.gcInfo.collectionTimeMs}ms total · ${m.gcInfo.lastGcCause}'
                    : 'Waiting...',
                icon: Icons.recycling,
                color: Colors.purpleAccent,
              ),
              SizedBox(width: 12),
              _SummaryCard(
                title: 'Deadlocks',
                value: m?.deadlockCount.toString() ?? '0',
                subtitle: m != null && m.deadlockCount > 0
                    ? '⚠️ Deadlock 감지!'
                    : 'Normal',
                icon: Icons.lock_outline,
                color: (m?.deadlockCount ?? 0) > 0
                    ? Colors.redAccent
                    : Colors.greenAccent,
              ),
            ],
          ),
          SizedBox(height: 20),

          // ── Heap 차트 ───────────────────────────────────────
          _ChartCard(
            title: 'Heap Usage (%)',
            child: _LineChart(
              data: provider.heapHistory,
              color: Colors.orangeAccent,
              maxY: 100,
            ),
          ),
          SizedBox(height: 16),

          // ── Thread Count 차트 ───────────────────────────────
          _ChartCard(
            title: 'Thread Count',
            child: _LineChart(
              data: provider.threadCountHistory,
              color: Colors.blueAccent,
              maxY: 200,
            ),
          ),
          SizedBox(height: 16),

          // ── Thread 상태 파이 차트 ────────────────────────────
          if (m != null)
            Row(
              children: [
                Expanded(
                  child: _ChartCard(
                    title: 'Thread States',
                    height: 200,
                    child: _ThreadPieChart(metrics: m),
                  ),
                ),
                SizedBox(width: 12),
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

  Color _heapColor(double pct) {
    if (pct > 85) return Colors.redAccent;
    if (pct > 65) return Colors.orangeAccent;
    return Colors.greenAccent;
  }
}

// ── 요약 카드 ──────────────────────────────────────────────────

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
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 18),
              SizedBox(width: 6),
              Text(title,
                  style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.6))),
            ]),
            SizedBox(height: 8),
            Text(value,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold,
                    color: color)),
            SizedBox(height: 4),
            Text(subtitle,
                style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.38)),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

// ── 차트 카드 래퍼 ──────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  final double height;

  const _ChartCard({
    required this.title, required this.child, this.height = 180,
  });

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
          Text(title,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.7))),
          SizedBox(height: 12),
          SizedBox(height: height, child: child),
        ],
      ),
    );
  }
}

// ── 라인 차트 ──────────────────────────────────────────────────

class _LineChart extends StatelessWidget {
  final List<double> data;
  final Color color;
  final double maxY;

  const _LineChart({required this.data, required this.color, required this.maxY});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(
          child: Text('데이터 대기 중...', style: TextStyle(color: Colors.white.withOpacity(0.38))));
    }
    final spots = data.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: Colors.white.withOpacity(0.1), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (v, _) => Text('${v.toInt()}',
                  style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.38))),
            ),
          ),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 2,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Thread 파이 차트 ────────────────────────────────────────────

class _ThreadPieChart extends StatelessWidget {
  final JvmMetrics metrics;
  const _ThreadPieChart({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return PieChart(PieChartData(
      sections: [
        PieChartSectionData(
            value: metrics.runningCount.toDouble(),
            color: Colors.greenAccent,
            title: 'Run\n${metrics.runningCount}',
            radius: 60, titleStyle: _style),
        PieChartSectionData(
            value: metrics.waitingCount.toDouble(),
            color: Colors.blueAccent,
            title: 'Wait\n${metrics.waitingCount}',
            radius: 60, titleStyle: _style),
        PieChartSectionData(
            value: metrics.blockedCount.toDouble(),
            color: Colors.orangeAccent,
            title: 'Block\n${metrics.blockedCount}',
            radius: 60, titleStyle: _style),
      ],
      sectionsSpace: 2,
    ));
  }

  TextStyle get _style =>
      TextStyle(fontSize: 10, fontWeight: FontWeight.bold);
}

// ── 메모리 바 차트 ──────────────────────────────────────────────

class _MemoryBarChart extends StatelessWidget {
  final JvmMetrics metrics;
  const _MemoryBarChart({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final heapUsed = metrics.heapUsedMb;
    final heapFree = metrics.heapMaxMb - heapUsed;
    final nonHeap = metrics.nonHeapUsed / (1024 * 1024);

    return BarChart(BarChartData(
      barGroups: [
        _bar(0, heapUsed, Colors.orangeAccent),
        _bar(1, heapFree, Colors.blueGrey),
        _bar(2, nonHeap, Colors.purpleAccent),
      ],
      titlesData: FlTitlesData(
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
      gridData: FlGridData(drawVerticalLine: false),
      borderData: FlBorderData(show: false),
    ));
  }

  BarChartGroupData _bar(int x, double y, Color color) =>
      BarChartGroupData(x: x, barRods: [
        BarChartRodData(
            toY: y, color: color, width: 30, borderRadius: BorderRadius.circular(4))
      ]);
}
