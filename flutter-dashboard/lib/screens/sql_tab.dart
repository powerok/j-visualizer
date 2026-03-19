// lib/screens/sql_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/profiler_provider.dart';
import '../models/profiler_models.dart';
import 'package:intl/intl.dart';

class SqlTab extends StatefulWidget {
  const SqlTab({super.key});

  @override
  State<SqlTab> createState() => _SqlTabState();
}

class _SqlTabState extends State<SqlTab> {
  bool _showSlowOnly = false;
  SqlEvent? _selectedEvent;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProfilerProvider>();
    var events = provider.sqlEvents;
    if (_showSlowOnly) events = events.where((e) => e.isSlowQuery).toList();

    final slowCount = provider.sqlEvents.where((e) => e.isSlowQuery).length;
    final totalCount = provider.sqlEvents.length;

    return Row(
      children: [
        // SQL 목록
        Expanded(
          child: Column(
            children: [
              // 툴바
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Theme.of(context).cardColor,
                child: Row(children: [
                  _Chip('전체 $totalCount건', Colors.blueAccent),
                  SizedBox(width: 8),
                  _Chip('Slow $slowCount건', Colors.redAccent),
                  const Spacer(),
                  Row(children: [
                    Text('Slow SQL만',
                        style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6))),
                    Switch(
                      value: _showSlowOnly,
                      onChanged: (v) => setState(() => _showSlowOnly = v),
                      activeColor: Colors.redAccent,
                    ),
                  ]),
                ]),
              ),
              // 목록
              Expanded(
                child: events.isEmpty
                    ? Center(
                        child: Text(
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
                          isSelected: _selectedEvent == events[i],
                          onTap: () => setState(() => _selectedEvent = events[i]),
                        ),
                      ),
              ),
            ],
          ),
        ),

        // 상세 패널
        if (_selectedEvent != null)
          Container(
            width: 340,
            color: const Color(0xFF0F3460),
            child: _SqlDetailPanel(
              event: _selectedEvent!,
              onClose: () => setState(() => _selectedEvent = null),
            ),
          ),
      ],
    );
  }
}

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

class _SqlEventTile extends StatelessWidget {
  final SqlEvent event;
  final bool isSelected;
  final VoidCallback onTap;
  const _SqlEventTile({required this.event, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = event.isSlowQuery ? Colors.redAccent : Colors.blueAccent;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      color: isSelected ? const Color(0xFF0F3460) : const Color(0xFF16213E),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Container(
              width: 4, height: 40,
              decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2)),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  event.sql.length > 80
                      ? '${event.sql.substring(0, 80)}...'
                      : event.sql,
                  style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7),
                      fontFamily: 'monospace'),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(DateFormat('HH:mm:ss.SSS').format(event.timestamp),
                    style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.38))),
              ]),
            ),
            SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${event.executionMs}ms',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold, color: color)),
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

class _SqlDetailPanel extends StatelessWidget {
  final SqlEvent event;
  final VoidCallback onClose;
  const _SqlDetailPanel({required this.event, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Text('SQL Detail',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
          const Spacer(),
          IconButton(icon: Icon(Icons.close, size: 16),
              onPressed: onClose, color: Colors.white.withOpacity(0.6)),
        ]),
      ),
      Divider(height: 1),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('실행 시간'),
            Text('${event.executionMs}ms',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold,
                    color: event.isSlowQuery ? Colors.redAccent : Colors.greenAccent)),
            SizedBox(height: 16),
            _label('SQL'),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(6),
              ),
              child: SelectableText(event.sql,
                  style: TextStyle(fontSize: 11, color: Colors.white,
                      fontFamily: 'monospace')),
            ),
            SizedBox(height: 12),
            _label('시각'),
            Text(DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(event.timestamp),
                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
            SizedBox(height: 12),
            _label('호출 위치'),
            Text(event.callerMethod.isEmpty ? '알 수 없음' : event.callerMethod,
                style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7),
                    fontFamily: 'monospace')),
          ]),
        ),
      ),
    ]);
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.38),
                letterSpacing: 0.8)),
      );
}
