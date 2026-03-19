// lib/screens/thread_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/profiler_provider.dart';
import '../models/profiler_models.dart';

class ThreadTab extends StatelessWidget {
  const ThreadTab({super.key});

  @override
  Widget build(BuildContext context) {
    final threads = context.watch<ProfilerProvider>().threads;

    if (threads.isEmpty) {
      return Center(
        child: Text('Thread 데이터 없음\nAgent 연결 후 약 30초 대기하세요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.38))),
      );
    }

    final blocked = threads.where((t) => t.isBlocked).toList();
    final running = threads.where((t) => t.isRunning).toList();
    final waiting = threads.where((t) => !t.isBlocked && !t.isRunning).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 요약
          Row(children: [
            _StateChip('RUNNABLE', running.length, Colors.greenAccent),
            SizedBox(width: 8),
            _StateChip('BLOCKED', blocked.length, Colors.redAccent),
            SizedBox(width: 8),
            _StateChip('WAITING', waiting.length, Colors.blueAccent),
            SizedBox(width: 8),
            _StateChip('TOTAL', threads.length, Colors.white.withOpacity(0.7)),
          ]),
          SizedBox(height: 16),

          if (blocked.isNotEmpty) ...[
            Text('🚨 BLOCKED Threads',
                style: TextStyle(color: Colors.redAccent,
                    fontWeight: FontWeight.bold, fontSize: 13)),
            SizedBox(height: 8),
            ...blocked.map((t) => _ThreadCard(thread: t)),
            SizedBox(height: 16),
          ],

          Text('All Threads',
              style: TextStyle(color: Colors.white.withOpacity(0.7),
                  fontWeight: FontWeight.bold, fontSize: 13)),
          SizedBox(height: 8),
          ...threads.map((t) => _ThreadCard(thread: t)),
        ],
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _StateChip(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text('$label: $count',
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      );
}

class _ThreadCard extends StatefulWidget {
  final ThreadInfo thread;
  const _ThreadCard({required this.thread});

  @override
  State<_ThreadCard> createState() => _ThreadCardState();
}

class _ThreadCardState extends State<_ThreadCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.thread;
    final stateColor = t.isBlocked
        ? Colors.redAccent
        : t.isRunning
            ? Colors.greenAccent
            : Colors.blueAccent;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: const Color(0xFF16213E),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: stateColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(t.state,
                    style: TextStyle(fontSize: 10, color: stateColor,
                        fontWeight: FontWeight.bold)),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(t.name,
                    style: TextStyle(fontSize: 12, color: Colors.white)),
              ),
              Text('#${t.id}',
                  style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.38))),
              Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                  size: 16, color: Colors.white.withOpacity(0.38)),
            ]),
            if (t.lockName != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Lock: ${t.lockName}',
                    style: TextStyle(fontSize: 10, color: Colors.orangeAccent,
                        fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis),
              ),
            if (_expanded && t.stackTrace.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: t.stackTrace
                        .take(10)
                        .map((s) => Text(s,
                            style: TextStyle(fontSize: 10,
                                color: Colors.white.withOpacity(0.54), fontFamily: 'monospace')))
                        .toList(),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
