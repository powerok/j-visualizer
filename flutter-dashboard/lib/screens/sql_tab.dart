// lib/screens/sql_tab.dart
// SQL 모니터링 탭: 실시간 SQL 이벤트 목록, 슬로우 쿼리 필터, 상세 패널 표시

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/profiler_provider.dart';
import '../models/profiler_models.dart';
import 'package:intl/intl.dart'; // 날짜/시각 포맷팅 패키지

// SQL 탭 위젯 (StatefulWidget: 필터 상태, 선택된 이벤트 상태 관리)
class SqlTab extends StatefulWidget {
  const SqlTab({super.key});

  @override
  State<SqlTab> createState() => _SqlTabState();
}

class _SqlTabState extends State<SqlTab> {
  // 슬로우 쿼리만 보기 필터 스위치 상태
  bool _showSlowOnly = false;
  // 현재 상세 패널에 표시 중인 SQL 이벤트 (null이면 패널 숨김)
  SqlEvent? _selectedEvent;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProfilerProvider>();
    // 전체 SQL 이벤트 목록 가져오기
    var events = provider.sqlEvents;
    // 슬로우 쿼리 필터 적용 시 슬로우 쿼리만 표시
    if (_showSlowOnly) events = events.where((e) => e.isSlowQuery).toList();

    // 슬로우 쿼리 건수와 전체 건수 계산
    final slowCount = provider.sqlEvents.where((e) => e.isSlowQuery).length;
    final totalCount = provider.sqlEvents.length;

    return Row(
      children: [
        // ── 왼쪽: SQL 이벤트 목록 영역 ────────────────────────────
        Expanded(
          child: Column(
            children: [
              // 툴바: 통계 칩 + 슬로우 쿼리 필터 스위치
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Theme.of(context).cardColor,
                child: Row(children: [
                  // 전체 건수 칩
                  _Chip('전체 $totalCount건', Colors.blueAccent),
                  SizedBox(width: 8),
                  // 슬로우 쿼리 건수 칩
                  _Chip('Slow $slowCount건', Colors.redAccent),
                  const Spacer(),
                  // 슬로우 쿼리만 보기 스위치
                  Row(children: [
                    Text('Slow SQL만',
                        style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6))),
                    Switch(
                      value: _showSlowOnly,
                      // 스위치 토글 시 필터 상태 변경 → 리빌드
                      onChanged: (v) => setState(() => _showSlowOnly = v),
                      activeColor: Colors.redAccent,
                    ),
                  ]),
                ]),
              ),
              // SQL 이벤트 목록
              Expanded(
                child: events.isEmpty
                    ? Center(
                        child: Text(
                          // 슬로우 필터 ON이면 "없음", 아니면 "데이터 없음"
                          _showSlowOnly ? 'Slow SQL 없음 ✅' : 'SQL 데이터 없음\nSQL Profiling이 활성화되어 있는지 확인하세요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withOpacity(0.38)),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: events.length,
                        itemBuilder: (ctx, i) => _SqlEventTile(
                          event: events[i],
                          // 현재 선택된 이벤트와 동일하면 강조 표시
                          isSelected: _selectedEvent == events[i],
                          // 탭 시 해당 이벤트를 선택 상태로 변경
                          onTap: () => setState(() => _selectedEvent = events[i]),
                        ),
                      ),
              ),
            ],
          ),
        ),

        // ── 오른쪽: SQL 상세 패널 (이벤트 선택 시에만 표시) ──────────
        if (_selectedEvent != null)
          Container(
            width: 340,
            color: const Color(0xFF0F3460),
            child: _SqlDetailPanel(
              event: _selectedEvent!,
              // 닫기 버튼 클릭 시 선택 해제
              onClose: () => setState(() => _selectedEvent = null),
            ),
          ),
      ],
    );
  }
}

// 통계 칩 위젯
class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  const _Chip(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(text, style: TextStyle(fontSize: 11, color: color)),
      );
}

// SQL 이벤트 목록 타일 위젯
class _SqlEventTile extends StatelessWidget {
  final SqlEvent event;
  final bool isSelected;
  final VoidCallback onTap;
  const _SqlEventTile({required this.event, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // 슬로우 쿼리면 빨간색, 아니면 파란색
    final color = event.isSlowQuery ? Colors.redAccent : Colors.blueAccent;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      // 선택된 이벤트는 더 진한 배경색
      color: isSelected ? const Color(0xFF0F3460) : const Color(0xFF16213E),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            // 좌측 색상 바 (슬로우 여부 시각화)
            Container(
              width: 4, height: 40,
              decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2)),
            ),
            SizedBox(width: 12),
            // SQL 내용 (80자 초과 시 잘라냄)
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  event.sql.length > 80 ? '${event.sql.substring(0, 80)}...' : event.sql,
                  style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7),
                      fontFamily: 'monospace'),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                // 실행 시각 (HH:mm:ss.SSS 형식)
                Text(DateFormat('HH:mm:ss.SSS').format(event.timestamp),
                    style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.38))),
              ]),
            ),
            SizedBox(width: 12),
            // 실행 시간 및 SLOW 레이블
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${event.executionMs}ms',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
              if (event.isSlowQuery)
                Text('SLOW', style: TextStyle(fontSize: 9,
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ]),
          ]),
        ),
      ),
    );
  }
}

// SQL 상세 패널 위젯
class _SqlDetailPanel extends StatelessWidget {
  final SqlEvent event;
  final VoidCallback onClose;
  const _SqlDetailPanel({required this.event, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // 패널 헤더
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Text('SQL Detail',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
          const Spacer(),
          // 닫기 버튼
          IconButton(icon: Icon(Icons.close, size: 16),
              onPressed: onClose, color: Colors.white.withOpacity(0.6)),
        ]),
      ),
      Divider(height: 1),
      // 상세 내용 스크롤 영역
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('실행 시간'),
            // 실행 시간 (슬로우면 빨강, 정상이면 초록)
            Text('${event.executionMs}ms',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                    color: event.isSlowQuery ? Colors.redAccent : Colors.greenAccent)),
            SizedBox(height: 16),
            _label('SQL'),
            // SQL 문자열 (선택/복사 가능)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(6),
              ),
              child: SelectableText(event.sql,
                  style: TextStyle(fontSize: 11, color: Colors.white, fontFamily: 'monospace')),
            ),
            SizedBox(height: 12),
            _label('시각'),
            // 실행 시각 (yyyy-MM-dd HH:mm:ss.SSS 형식)
            Text(DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(event.timestamp),
                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
            SizedBox(height: 12),
            _label('호출 위치'),
            // 호출 메서드명 (없으면 '알 수 없음')
            Text(event.callerMethod.isEmpty ? '알 수 없음' : event.callerMethod,
                style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7),
                    fontFamily: 'monospace')),
          ]),
        ),
      ),
    ]);
  }

  // 필드 레이블 위젯 생성 헬퍼 메서드
  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.38),
                letterSpacing: 0.8)),
      );
}
