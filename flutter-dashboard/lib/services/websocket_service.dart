// lib/services/websocket_service.dart
// 백엔드 WebSocket 서버와의 연결 및 실시간 데이터 수신을 담당하는 서비스 클래스

// 비동기 스트림 처리를 위한 dart:async 라이브러리
import 'dart:async';
// JSON 인코딩/디코딩을 위한 dart:convert 라이브러리
import 'dart:convert';
// WebSocket 채널 패키지 (pub.dev: web_socket_channel)
import 'package:web_socket_channel/web_socket_channel.dart';
// 데이터 모델 클래스 임포트
import '../models/profiler_models.dart';

// WebSocket 연결 상태를 나타내는 열거형(enum)
enum ConnectionState {
  disconnected,  // 연결 끊김 상태
  connecting,    // 연결 시도 중
  connected,     // 연결 완료
  error          // 오류 발생
}

// WebSocket 서비스 클래스: 백엔드와 실시간 통신 담당
class WebSocketService {
  // WebSocket 채널 객체 (연결되지 않은 경우 null)
  WebSocketChannel? _channel;
  // 현재 연결 상태 (초기값: 연결 끊김)
  ConnectionState _state = ConnectionState.disconnected;
  // 연결된 서버 URL (WebSocket 형식: ws://)
  String? _serverUrl;

  // JVM 메트릭 데이터를 전달하는 브로드캐스트 스트림 컨트롤러
  final _metricsController = StreamController<JvmMetrics>.broadcast();
  // Flame Graph 노드 데이터를 전달하는 브로드캐스트 스트림 컨트롤러
  final _flameNodeController = StreamController<FlameNode>.broadcast();
  // SQL 이벤트 데이터를 전달하는 브로드캐스트 스트림 컨트롤러
  final _sqlEventController = StreamController<SqlEvent>.broadcast();
  // 스레드 정보 목록을 전달하는 브로드캐스트 스트림 컨트롤러
  final _threadInfoController = StreamController<List<ThreadInfo>>.broadcast();
  // 알림 데이터를 전달하는 브로드캐스트 스트림 컨트롤러
  final _alertController = StreamController<ProfilerAlert>.broadcast();
  // 연결 상태 변경을 전달하는 브로드캐스트 스트림 컨트롤러
  final _stateController = StreamController<ConnectionState>.broadcast();

  // 각 스트림 컨트롤러의 외부 노출용 getter들
  Stream<JvmMetrics> get metricsStream => _metricsController.stream;
  Stream<FlameNode> get flameNodeStream => _flameNodeController.stream;
  Stream<SqlEvent> get sqlEventStream => _sqlEventController.stream;
  Stream<List<ThreadInfo>> get threadStream => _threadInfoController.stream;
  Stream<ProfilerAlert> get alertStream => _alertController.stream;
  Stream<ConnectionState> get stateStream => _stateController.stream;
  // 현재 연결 상태를 반환하는 getter
  ConnectionState get state => _state;

  // 서버에 WebSocket 연결을 시도하는 비동기 메서드
  Future<void> connect(String serverUrl) async {
    // HTTP URL을 WebSocket URL로 변환 (http → ws, https → wss)
    _serverUrl = serverUrl.replaceAll('http://', 'ws://').replaceAll('https://', 'wss://');
    // '/ws/dashboard' 엔드포인트가 없으면 추가
    if (!_serverUrl!.endsWith('/ws/dashboard')) {
      _serverUrl = '${_serverUrl!}/ws/dashboard';
    }

    // 연결 시도 상태로 변경
    _setState(ConnectionState.connecting);
    try {
      // WebSocket 채널 생성 및 서버 연결
      _channel = WebSocketChannel.connect(Uri.parse(_serverUrl!));
      // 연결 완료 상태로 변경
      _setState(ConnectionState.connected);

      // 서버에서 오는 메시지 스트림 구독
      _channel!.stream.listen(
        // 메시지 수신 시 처리
        _onMessage,
        // 오류 발생 시 오류 상태로 변경
        onError: (error) {
          _setState(ConnectionState.error);
        },
        // 연결 종료 시 연결 끊김 상태로 변경
        onDone: () {
          _setState(ConnectionState.disconnected);
        },
      );
    } catch (e) {
      // 연결 실패 시 오류 상태로 변경
      _setState(ConnectionState.error);
    }
  }

  // 서버로부터 수신한 메시지를 파싱하고 적절한 스트림에 전달하는 메서드
  void _onMessage(dynamic raw) {
    try {
      // JSON 문자열을 Map으로 디코딩
      final Map<String, dynamic> envelope = jsonDecode(raw as String);
      // 메시지 타입 추출 (없으면 빈 문자열)
      final type = envelope['type'] as String? ?? '';
      // 실제 데이터 페이로드 추출 (data 키 우선, 없으면 envelope 자체 사용)
      final data = envelope['data'] ?? envelope;

      // 메시지 타입에 따라 적절한 스트림 컨트롤러에 데이터 전달
      switch (type) {
        // JVM 메트릭 수신 시
        case 'METRICS':
          // JvmMetrics 객체로 변환 후 스트림에 추가
          final metrics = JvmMetrics.fromJson(data as Map<String, dynamic>);
          _metricsController.add(metrics);

        // CPU 프로파일링 데이터 수신 시
        case 'CPU_PROFILE':
          // 'data' 하위 필드에서 Flame Graph 데이터 추출
          final flameData = (data as Map<String, dynamic>)['data'];
          if (flameData != null) {
            // FlameNode 트리 구조로 변환 후 스트림에 추가
            final node = FlameNode.fromJson(flameData as Map<String, dynamic>);
            _flameNodeController.add(node);
          }

        // SQL 이벤트 수신 시
        case 'SQL_EVENT':
          // SqlEvent 객체로 변환 후 스트림에 추가
          _sqlEventController.add(SqlEvent.fromJson(data as Map<String, dynamic>));

        // 스레드 덤프 수신 시
        case 'THREAD_DUMP':
          // 'threads' 배열 추출 (없으면 빈 리스트)
          final threads = (data as Map<String, dynamic>)['threads'] as List<dynamic>? ?? [];
          // 각 스레드를 ThreadInfo 객체로 변환하여 리스트로 스트림에 추가
          _threadInfoController.add(
              threads.map((t) => ThreadInfo.fromJson(t as Map<String, dynamic>)).toList());

        // 알림(경보) 수신 시
        case 'ALERT':
          final d = data as Map<String, dynamic>;
          // ProfilerAlert 객체 생성 후 스트림에 추가
          _alertController.add(ProfilerAlert(
            // 알림 유형
            type: d['type']?.toString() ?? 'ALERT',
            // 알림 메시지
            message: d['message']?.toString() ?? '',
            // 현재 시각으로 타임스탬프 설정
            timestamp: DateTime.now(),
          ));
      }
    } catch (_) {
      // 파싱 실패 시 무시 (예외를 외부로 전파하지 않음)
    }
  }

  // WebSocket 연결을 끊는 메서드
  void disconnect() {
    // 채널의 싱크를 닫아 연결 종료
    _channel?.sink.close();
    // 채널 참조 해제
    _channel = null;
    // 연결 끊김 상태로 변경
    _setState(ConnectionState.disconnected);
  }

  // 연결 상태를 변경하고 상태 스트림에 알리는 내부 메서드
  void _setState(ConnectionState s) {
    // 현재 상태 업데이트
    _state = s;
    // 상태 스트림에 새 상태 전달 (구독자들에게 알림)
    _stateController.add(s);
  }

  // 서비스 리소스를 정리하는 메서드 (화면 종료 시 호출)
  void dispose() {
    // WebSocket 연결 종료
    disconnect();
    // 모든 스트림 컨트롤러 닫기 (메모리 누수 방지)
    _metricsController.close();
    _flameNodeController.close();
    _sqlEventController.close();
    _threadInfoController.close();
    _alertController.close();
    _stateController.close();
  }
}
