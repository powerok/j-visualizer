// lib/screens/thread_tab.dart
// 스레드 상태 탭: JVM 스레드 목록 및 상태별 분류, 스택 트레이스 표시

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/profiler_provider.dart';
import '../models/profiler_models.dart';

// 스레드 탭 위젯 (StatelessWidget: Provider에서 스레드 목록을 읽어 렌더링)
class ThreadTab extends StatelessWidget {
  const ThreadTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Provider에서 최신 스레드 목록 조회
    final threads = context.watch<ProfilerProvider>().threads;

    // 스레드 데이터 없으면 안내 메시지 표시
    if (threads.isEmpty) {
      return Center(
        child: Text('Thread 데이터 없음\nAgent 연결 후 약 30초 대기하세요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.38))),
      );
    }

    // 스레드 상태별 분류
    final blocked = threads.where((t) => t.isBlocked).toList(); // BLOCKED 상태
    final running = threads.where((t) => t.isRunning).toList(); // RUNNABLE 상태
    final waiting = threads.where((t) => !t.isBlocked && !t.isRunning).toList(); // WAITING 등

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 상태별 요약 칩 행 ────────────────────────────────────
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

          // ── BLOCKED 스레드 섹션 (있을 때만 표시, 위험 경고) ────────
          if (blocked.isNotEmpty) ...[
            Text('🚨 BLOCKED Threads',
                style: TextStyle(color: Colors.redAccent,
                    fontWeight: FontWeight.bold, fontSize: 13)),
            SizedBox(height: 8),
            // BLOCKED 스레드 카드 목록
            ...blocked.map((t) => _ThreadCard(thread: t)),
            SizedBox(height: 16),
          ],

          // ── 전체 스레드 목록 섹션 ────────────────────────────────
          Text('All Threads',
              style: TextStyle(color: Colors.white.withOpacity(0.7),
                  fontWeight: FontWeight.bold, fontSize: 13)),
          SizedBox(height: 8),
          // 전체 스레드 카드 목록
          ...threads.map((t) => _ThreadCard(thread: t)),
        ],
      ),
    );
  }
}

// 상태별 스레드 수를 표시하는 칩 위젯
class _StateChip extends StatelessWidget {
  final String label; // 상태 레이블 (예: 'RUNNABLE')
  final int count;    // 해당 상태 스레드 수
  final Color color;  // 강조 색상

  const _StateChip(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        // "상태: 수" 형태로 표시
        child: Text('$label: $count',
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      );
}

// 개별 스레드 정보 카드 위젯 (StatefulWidget: 스택 트레이스 펼침/접힘 상태 관리)
class _ThreadCard extends StatefulWidget {
  final ThreadInfo thread;
  const _ThreadCard({required this.thread});

  @override
  State<_ThreadCard> createState() => _ThreadCardState();
}

class _ThreadCardState extends State<_ThreadCard> {
  // 스택 트레이스 펼침 여부 (기본: 접힘)
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.thread;
    // 스레드 상태에 따라 색상 결정
    final stateColor = t.isBlocked
        ? Colors.redAccent    // BLOCKED: 빨간색
        : t.isRunning
            ? Colors.greenAccent // RUNNABLE: 초록색
            : Colors.blueAccent; // WAITING 등: 파란색

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: const Color(0xFF16213E),
      child: InkWell(
        // 카드 탭 시 스택 트레이스 펼침/접힘 토글
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── 스레드 헤더 행 (상태 배지 + 이름 + ID + 화살표) ─────
            Row(children: [
              // 스레드 상태 배지
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
              // 스레드 이름 (남은 공간 모두 차지)
              Expanded(
                child: Text(t.name,
                    style: TextStyle(fontSize: 12, color: Colors.white)),
              ),
              // 스레드 ID
              Text('#${t.id}',
                  style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.38))),
              // 펼침/접힘 화살표 아이콘
              Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                  size: 16, color: Colors.white.withOpacity(0.38)),
            ]),
            // ── 락 정보 (보유 중인 락이 있을 때만 표시) ──────────────
            if (t.lockName != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Lock: ${t.lockName}',
                    style: TextStyle(fontSize: 10, color: Colors.orangeAccent,
                        fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis),
              ),
            // ── 스택 트레이스 (펼침 상태이고 스택이 있을 때만 표시) ──
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
                    // 스택 트레이스 최대 10줄만 표시
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
