// lib/providers/profiler_provider.dart
import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../models/profiler_models.dart';
import '../services/websocket_service.dart';

class ProfilerProvider extends ChangeNotifier {
  final WebSocketService _ws = WebSocketService();

  final Queue<JvmMetrics> _metricsHistory = Queue();
  static const int _maxHistory = 60;

  JvmMetrics? _latestMetrics;
  FlameNode? _latestFlameNode;
  List<ThreadInfo> _threads = [];
  final List<SqlEvent> _sqlEvents = [];
  final List<ProfilerAlert> _alerts = [];

  bool _isConnected = false;
  String _serverUrl = 'http://localhost:8080';
  String _connectionStatus = '연결 안됨';

  // ── Example App URL (API Test 탭에서 사용) ──────────────────────
  String _exampleAppUrl = 'http://localhost:8090';
  String get exampleAppUrl => _exampleAppUrl;

  void setExampleAppUrl(String url) {
    if (url.isNotEmpty) {
      _exampleAppUrl = url;
      notifyListeners();
    }
  }

  final List<StreamSubscription> _subs = [];

  ProfilerProvider() {
    _subs.add(_ws.stateStream.listen(_onStateChange));
    _subs.add(_ws.metricsStream.listen(_onMetrics));
    _subs.add(_ws.flameNodeStream.listen(_onFlameNode));
    _subs.add(_ws.sqlEventStream.listen(_onSqlEvent));
    _subs.add(_ws.threadStream.listen(_onThreadDump));
    _subs.add(_ws.alertStream.listen(_onAlert));
  }

  bool get isConnected => _isConnected;
  String get serverUrl => _serverUrl;
  String get connectionStatus => _connectionStatus;
  JvmMetrics? get latestMetrics => _latestMetrics;
  FlameNode? get latestFlameNode => _latestFlameNode;
  List<ThreadInfo> get threads => List.unmodifiable(_threads);
  List<SqlEvent> get sqlEvents => List.unmodifiable(_sqlEvents);
  List<ProfilerAlert> get alerts => List.unmodifiable(_alerts);
  List<JvmMetrics> get metricsHistory => List.unmodifiable(_metricsHistory);

  List<double> get heapHistory =>
      _metricsHistory.map((m) => m.heapUsedPercent).toList();
  List<double> get threadCountHistory =>
      _metricsHistory.map((m) => m.threadCount.toDouble()).toList();

  Future<void> connect(String url) async {
    _serverUrl = url;
    _connectionStatus = '연결 중...';
    notifyListeners();
    await _ws.connect(url);
  }

  void disconnect() {
    _ws.disconnect();
  }

  void clearAlerts() {
    _alerts.clear();
    notifyListeners();
  }

  void _onStateChange(ConnectionState state) {
    _isConnected = state == ConnectionState.connected;
    _connectionStatus = switch (state) {
      ConnectionState.connected    => '연결됨',
      ConnectionState.connecting   => '연결 중...',
      ConnectionState.disconnected => '연결 안됨',
      ConnectionState.error        => '연결 오류',
    };
    notifyListeners();
  }

  void _onMetrics(JvmMetrics m) {
    _latestMetrics = m;
    _metricsHistory.addLast(m);
    if (_metricsHistory.length > _maxHistory) _metricsHistory.removeFirst();
    notifyListeners();
  }

  void _onFlameNode(FlameNode node) {
    _latestFlameNode = node;
    notifyListeners();
  }

  void _onSqlEvent(SqlEvent event) {
    _sqlEvents.insert(0, event);
    if (_sqlEvents.length > 200) _sqlEvents.removeLast();
    notifyListeners();
  }

  void _onThreadDump(List<ThreadInfo> threads) {
    _threads = threads;
    notifyListeners();
  }

  void _onAlert(ProfilerAlert alert) {
    _alerts.insert(0, alert);
    if (_alerts.length > 50) _alerts.removeLast();
    notifyListeners();
  }

  @override
  void dispose() {
    for (final sub in _subs) { sub.cancel(); }
    _ws.dispose();
    super.dispose();
  }
}
