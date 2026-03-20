// lib/widgets/header_widget.dart
// 앱 상단 헤더: 실시간 JVM 메트릭 요약 칩과 연결 상태 표시

// Flutter Material 위젯 라이브러리
import 'package:flutter/material.dart';
// 상태 관리 패키지
import 'package:provider/provider.dart';
// 앱 전역 상태 Provider
import '../providers/profiler_provider.dart';

// 헤더 위젯 (StatelessWidget: 자체 상태 없음, Provider에서 데이터 읽기)
class HeaderWidget extends StatelessWidget {
  const HeaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Provider에서 앱 상태 구독 (변경 시 자동 리빌드)
    final provider = context.watch<ProfilerProvider>();
    // 최신 JVM 메트릭 데이터 (null이면 아직 수신 전)
    final m = provider.latestMetrics;

    return Container(
      // 헤더 높이 고정
      height: 56,
      // 좌우 패딩
      padding: const EdgeInsets.symmetric(horizontal: 20),
      // 카드 배경색
      color: Theme.of(context).cardColor,
      child: Row(
        children: [
          // 헤더 제목 텍스트
          Text('Live Profiling',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                  color: Colors.white.withOpacity(0.7))),
          SizedBox(width: 24),

          // 메트릭 데이터가 있을 때만 요약 칩 표시
          if (m != null) ...[
            // Heap 사용률 칩
            _MetricChip(
              icon: Icons.memory,
              label: 'Heap',
              // 소수점 1자리까지 퍼센트 표시
              value: '${m.heapUsedPercent.toStringAsFixed(1)}%',
              // 80% 초과 시 빨간색, 60% 초과 시 주황색, 그 외 초록색
              color: m.heapUsedPercent > 80
                  ? Colors.redAccent
                  : m.heapUsedPercent > 60
                      ? Colors.orangeAccent
                      : Colors.greenAccent,
            ),
            SizedBox(width: 8),
            // 스레드 수 칩
            _MetricChip(
              icon: Icons.swap_horiz,
              label: 'Threads',
              // 전체 스레드 수 표시
              value: '${m.threadCount}',
              // BLOCKED 스레드가 5개 초과 시 주황색, 정상 시 파란색
              color: m.blockedCount > 5 ? Colors.orangeAccent : Colors.blueAccent,
            ),
            SizedBox(width: 8),
            // GC 횟수 칩
            _MetricChip(
              icon: Icons.storage,
              label: 'GC',
              // 누적 GC 횟수 표시
              value: '${m.gcInfo.collectionCount}x',
              // 보라색
              color: Colors.purpleAccent,
            ),
            // 데드락이 감지된 경우에만 데드락 칩 추가 표시
            if (m.deadlockCount > 0) ...[
              SizedBox(width: 8),
              _MetricChip(
                icon: Icons.lock,
                label: 'DEADLOCK',
                // 데드락 스레드 수 표시
                value: '${m.deadlockCount}',
                // 빨간색 (위험 경고)
                color: Colors.redAccent,
              ),
            ],
          ] else
            // 데이터 미수신 시 대기 메시지 표시
            Text('Waiting for data...',
                style: TextStyle(color: Colors.white.withOpacity(0.38), fontSize: 12)),

          // 남은 공간을 모두 차지하여 LIVE 인디케이터를 우측 정렬
          const Spacer(),

          // 연결 중일 때만 LIVE 인디케이터 표시
          if (provider.isConnected)
            Row(children: [
              // 녹색 원형 인디케이터 (실시간 연결 시각적 표시)
              Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                    color: Colors.greenAccent, shape: BoxShape.circle),
              ),
              SizedBox(width: 6),
              // 'LIVE' 텍스트 레이블
              Text('LIVE',
                  style: TextStyle(fontSize: 11, color: Colors.greenAccent,
                      fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            ]),
        ],
      ),
    );
  }
}

// 헤더에 표시되는 개별 메트릭 칩 위젯
class _MetricChip extends StatelessWidget {
  // 칩 좌측 아이콘
  final IconData icon;
  // 메트릭 이름 레이블
  final String label;
  // 메트릭 값 문자열
  final String value;
  // 칩 강조색 (값에 따라 다름)
  final Color color;

  const _MetricChip({
    required this.icon, required this.label,
    required this.value, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // 좌우/상하 내부 여백
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        // 칩 배경색: 강조색의 12% 불투명도
        color: color.withOpacity(0.12),
        // 둥근 모서리 (pill 형태)
        borderRadius: BorderRadius.circular(20),
        // 테두리: 강조색 40% 불투명도
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        // 내용물만큼만 너비 차지
        mainAxisSize: MainAxisSize.min,
        children: [
          // 메트릭 아이콘 (작은 크기)
          Icon(icon, size: 13, color: color),
          SizedBox(width: 5),
          // "레이블: 값" 형태로 텍스트 표시
          Text('$label: $value',
              style: TextStyle(fontSize: 12, color: color,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
