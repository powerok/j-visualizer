// lib/services/websocket_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/profiler_models.dart';

enum ConnectionState { disconnected, connecting, connected, error }

class WebSocketService {
  WebSocketChannel? _channel;
  ConnectionState _state = ConnectionState.disconnected;
  String? _serverUrl;

  final _metricsController = StreamController<JvmMetrics>.broadcast();
  final _flameNodeController = StreamController<FlameNode>.broadcast();
  final _sqlEventController = StreamController<SqlEvent>.broadcast();
  final _threadInfoController = StreamController<List<ThreadInfo>>.broadcast();
  final _alertController = StreamController<ProfilerAlert>.broadcast();
  final _stateController = StreamController<ConnectionState>.broadcast();

  Stream<JvmMetrics> get metricsStream => _metricsController.stream;
  Stream<FlameNode> get flameNodeStream => _flameNodeController.stream;
  Stream<SqlEvent> get sqlEventStream => _sqlEventController.stream;
  Stream<List<ThreadInfo>> get threadStream => _threadInfoController.stream;
  Stream<ProfilerAlert> get alertStream => _alertController.stream;
  Stream<ConnectionState> get stateStream => _stateController.stream;
  ConnectionState get state => _state;

  Future<void> connect(String serverUrl) async {
    _serverUrl = serverUrl.replaceAll('http://', 'ws://').replaceAll('https://', 'wss://');
    if (!_serverUrl!.endsWith('/ws/dashboard')) {
      _serverUrl = '${_serverUrl!}/ws/dashboard';
    }

    _setState(ConnectionState.connecting);
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_serverUrl!));
      _setState(ConnectionState.connected);

      _channel!.stream.listen(
        _onMessage,
        onError: (error) {
          _setState(ConnectionState.error);
        },
        onDone: () {
          _setState(ConnectionState.disconnected);
        },
      );
    } catch (e) {
      _setState(ConnectionState.error);
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final Map<String, dynamic> envelope = jsonDecode(raw as String);
      final type = envelope['type'] as String? ?? '';
      final data = envelope['data'] ?? envelope;

      switch (type) {
        case 'METRICS':
          final metrics = JvmMetrics.fromJson(data as Map<String, dynamic>);
          _metricsController.add(metrics);

        case 'CPU_PROFILE':
          final flameData = (data as Map<String, dynamic>)['data'];
          if (flameData != null) {
            final node = FlameNode.fromJson(flameData as Map<String, dynamic>);
            _flameNodeController.add(node);
          }

        case 'SQL_EVENT':
          _sqlEventController.add(SqlEvent.fromJson(data as Map<String, dynamic>));

        case 'THREAD_DUMP':
          final threads = (data as Map<String, dynamic>)['threads'] as List<dynamic>? ?? [];
          _threadInfoController.add(
              threads.map((t) => ThreadInfo.fromJson(t as Map<String, dynamic>)).toList());

        case 'ALERT':
          final d = data as Map<String, dynamic>;
          _alertController.add(ProfilerAlert(
            type: d['type']?.toString() ?? 'ALERT',
            message: d['message']?.toString() ?? '',
            timestamp: DateTime.now(),
          ));
      }
    } catch (_) {}
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _setState(ConnectionState.disconnected);
  }

  void _setState(ConnectionState s) {
    _state = s;
    _stateController.add(s);
  }

  void dispose() {
    disconnect();
    _metricsController.close();
    _flameNodeController.close();
    _sqlEventController.close();
    _threadInfoController.close();
    _alertController.close();
    _stateController.close();
  }
}
