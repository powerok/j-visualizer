// lib/widgets/header_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/profiler_provider.dart';

class HeaderWidget extends StatelessWidget {
  const HeaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProfilerProvider>();
    final m = provider.latestMetrics;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: Theme.of(context).cardColor,
      child: Row(
        children: [
          Text('Live Profiling',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                  color: Colors.white.withOpacity(0.7))),
          SizedBox(width: 24),

          // 실시간 메트릭 요약 칩들
          if (m != null) ...[
            _MetricChip(
              icon: Icons.memory,
              label: 'Heap',
              value: '${m.heapUsedPercent.toStringAsFixed(1)}%',
              color: m.heapUsedPercent > 80
                  ? Colors.redAccent
                  : m.heapUsedPercent > 60
                      ? Colors.orangeAccent
                      : Colors.greenAccent,
            ),
            SizedBox(width: 8),
            _MetricChip(
              icon: Icons.swap_horiz,
              label: 'Threads',
              value: '${m.threadCount}',
              color: m.blockedCount > 5 ? Colors.orangeAccent : Colors.blueAccent,
            ),
            SizedBox(width: 8),
            _MetricChip(
              icon: Icons.storage,
              label: 'GC',
              value: '${m.gcInfo.collectionCount}x',
              color: Colors.purpleAccent,
            ),
            if (m.deadlockCount > 0) ...[
              SizedBox(width: 8),
              _MetricChip(
                icon: Icons.lock,
                label: 'DEADLOCK',
                value: '${m.deadlockCount}',
                color: Colors.redAccent,
              ),
            ],
          ] else
            Text('Waiting for data...',
                style: TextStyle(color: Colors.white.withOpacity(0.38), fontSize: 12)),

          const Spacer(),

          // 라이브 인디케이터
          if (provider.isConnected)
            Row(children: [
              Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                    color: Colors.greenAccent, shape: BoxShape.circle),
              ),
              SizedBox(width: 6),
              Text('LIVE',
                  style: TextStyle(fontSize: 11, color: Colors.greenAccent,
                      fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            ]),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;

  const _MetricChip({
    required this.icon, required this.label,
    required this.value, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          SizedBox(width: 5),
          Text('$label: $value',
              style: TextStyle(fontSize: 12, color: color,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
