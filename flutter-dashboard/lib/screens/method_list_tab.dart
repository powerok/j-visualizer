// lib/screens/method_list_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/profiler_provider.dart';
import '../models/profiler_models.dart';

class MethodListTab extends StatefulWidget {
  const MethodListTab({super.key});

  @override
  State<MethodListTab> createState() => _MethodListTabState();
}

class _MethodListTabState extends State<MethodListTab> {
  int _sortColumnIndex = 1;
  bool _sortAscending = false;

  List<_MethodRow> _buildRows(FlameNode? root) {
    if (root == null) return [];
    final map = <String, _MethodRow>{};
    _collect(root, map, root.value);
    return map.values.toList();
  }

  void _collect(FlameNode node, Map<String, _MethodRow> map, int total) {
    if (node.name != 'root') {
      map.update(
        node.name,
        (r) => _MethodRow(
          name: r.name,
          totalSamples: r.totalSamples + node.value,
          selfSamples: r.selfSamples + node.selfTimeMs,
          totalPct: (r.totalSamples + node.value) / total * 100,
        ),
        ifAbsent: () => _MethodRow(
          name: node.name,
          totalSamples: node.value,
          selfSamples: node.selfTimeMs,
          totalPct: node.value / total * 100,
        ),
      );
    }
    for (final c in node.children) { _collect(c, map, total); }
  }

  @override
  Widget build(BuildContext context) {
    final root = context.watch<ProfilerProvider>().latestFlameNode;
    var rows = _buildRows(root);

    // 정렬
    rows.sort((a, b) {
      final cmp = _sortColumnIndex == 0
          ? a.name.compareTo(b.name)
          : _sortColumnIndex == 1
              ? a.totalSamples.compareTo(b.totalSamples)
              : a.selfSamples.compareTo(b.selfSamples);
      return _sortAscending ? cmp : -cmp;
    });

    if (rows.isEmpty) {
      return Center(
        child: Text('Method 데이터 없음\nCPU 프로파일링을 시작하세요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.38))),
      );
    }

    return SingleChildScrollView(
      child: DataTable(
        sortColumnIndex: _sortColumnIndex,
        sortAscending: _sortAscending,
        columnSpacing: 20,
        headingRowColor: WidgetStateProperty.all(const Color(0xFF0F3460)),
        columns: [
          DataColumn(
            label: Text('Method', style: TextStyle(color: Colors.white.withOpacity(0.7))),
            onSort: (i, asc) => setState(() {
              _sortColumnIndex = i; _sortAscending = asc;
            }),
          ),
          DataColumn(
            label: Text('Total Samples', style: TextStyle(color: Colors.white.withOpacity(0.7))),
            numeric: true,
            onSort: (i, asc) => setState(() {
              _sortColumnIndex = i; _sortAscending = asc;
            }),
          ),
          DataColumn(
            label: Text('Self Time(ms)', style: TextStyle(color: Colors.white.withOpacity(0.7))),
            numeric: true,
            onSort: (i, asc) => setState(() {
              _sortColumnIndex = i; _sortAscending = asc;
            }),
          ),
          DataColumn(
            label: Text('% Total', style: TextStyle(color: Colors.white.withOpacity(0.7))),
            numeric: true,
          ),
        ],
        rows: rows.map((r) => DataRow(cells: [
          DataCell(Tooltip(
            message: r.name,
            child: Text(r.shortName,
                style: TextStyle(fontSize: 12, color: Colors.white,
                    fontFamily: 'monospace'),
                overflow: TextOverflow.ellipsis),
          )),
          DataCell(Text('${r.totalSamples}',
              style: TextStyle(color: Colors.blueAccent))),
          DataCell(Text('${r.selfSamples}ms',
              style: TextStyle(
                  color: r.selfSamples > 1000 ? Colors.redAccent : Colors.white.withOpacity(0.7)))),
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

class _MethodRow {
  final String name;
  final int totalSamples, selfSamples;
  final double totalPct;

  _MethodRow({required this.name, required this.totalSamples,
      required this.selfSamples, required this.totalPct});

  String get shortName {
    final parts = name.split('.');
    return parts.length > 2 ? '${parts[parts.length - 2]}.${parts.last}' : name;
  }
}
