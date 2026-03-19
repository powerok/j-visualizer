// lib/widgets/sidebar_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/profiler_provider.dart';

class SidebarWidget extends StatefulWidget {
  const SidebarWidget({super.key});

  @override
  State<SidebarWidget> createState() => _SidebarWidgetState();
}

class _SidebarWidgetState extends State<SidebarWidget> {
  final _urlController = TextEditingController(text: 'http://localhost:8080');

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProfilerProvider>();
    final isConnected = provider.isConnected;

    return Container(
      width: 240,
      color: Theme.of(context).cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.analytics, color: Colors.blueAccent, size: 28),
                SizedBox(width: 10),
                Text('J-Visualizer',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ],
            ),
          ),
          Divider(),

          // 서버 URL
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Backend Server',
                    style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.6))),
                SizedBox(height: 6),
                TextField(
                  controller: _urlController,
                  style: TextStyle(fontSize: 12, color: Colors.white),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6)),
                    hintText: 'http://localhost:8080',
                    hintStyle: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.38)),
                  ),
                ),
              ],
            ),
          ),

          // 연결/해제 버튼
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (isConnected) {
                    provider.disconnect();
                  } else {
                    provider.connect(_urlController.text.trim());
                  }
                },
                icon: Icon(isConnected ? Icons.link_off : Icons.link, size: 16),
                label: Text(isConnected ? 'Disconnect' : 'Connect',
                    style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isConnected ? Colors.red.shade700 : Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          SizedBox(height: 16),
          Divider(),

          // 연결 상태
          Padding(
            padding: const EdgeInsets.all(12),
            child: _StatusTile(
              label: 'Connection',
              value: provider.connectionStatus,
              color: isConnected ? Colors.greenAccent : Colors.redAccent,
            ),
          ),

          Divider(),
          Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Text('PROFILING MODE',
                style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.38),
                    letterSpacing: 1.2)),
          ),
          // 모드 선택
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                _ModeRadio(label: '● Sampling (권장)', value: 'sampling'),
                _ModeRadio(label: '● Instrumenting', value: 'instrumenting'),
              ],
            ),
          ),

          const Spacer(),
          Divider(),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('v1.0.0 · J-Visualizer',
                style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.38))),
          ),
        ],
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatusTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.38))),
          Text(value, style: TextStyle(fontSize: 12, color: color)),
        ]),
      ],
    );
  }
}

class _ModeRadio extends StatelessWidget {
  final String label, value;
  const _ModeRadio({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label,
          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
    );
  }
}
