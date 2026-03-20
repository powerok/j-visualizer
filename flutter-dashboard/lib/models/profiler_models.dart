// lib/models/profiler_models.dart
// JVisualizer 앱에서 사용하는 모든 데이터 모델 클래스 정의 파일

/// JVM 실시간 메트릭 모델: 에이전트에서 수신한 JVM 상태 정보를 담는 클래스
class JvmMetrics {
  // 데이터 수집 시각
  final DateTime timestamp;
  // 현재 사용 중인 Heap 메모리 (바이트 단위)
  final int heapUsed;
  // JVM에 설정된 최대 Heap 메모리 크기 (바이트 단위)
  final int heapMax;
  // Heap 메모리 사용률 (0.0 ~ 100.0 퍼센트)
  final double heapUsedPercent;
  // Non-Heap(메타스페이스 등) 사용 메모리 (바이트 단위)
  final int nonHeapUsed;
  // 현재 JVM 전체 스레드 수
  final int threadCount;
  // RUNNABLE 상태 스레드 수
  final int runningCount;
  // WAITING/TIMED_WAITING 상태 스레드 수
  final int waitingCount;
  // BLOCKED 상태 스레드 수 (락 대기)
  final int blockedCount;
  // 데드락 감지된 스레드 수
  final int deadlockCount;
  // GC(가비지 컬렉션) 관련 정보 객체
  final GcInfo gcInfo;

  // 생성자: 모든 필드를 named parameter로 받으며 required(필수) 지정
  JvmMetrics({
    required this.timestamp,
    required this.heapUsed,
    required this.heapMax,
    required this.heapUsedPercent,
    required this.nonHeapUsed,
    required this.threadCount,
    required this.runningCount,
    required this.waitingCount,
    required this.blockedCount,
    required this.deadlockCount,
    required this.gcInfo,
  });

  // JSON 맵으로부터 JvmMetrics 객체 생성하는 팩토리 생성자
  factory JvmMetrics.fromJson(Map<String, dynamic> json) {
    // 'jvm_info' 키가 있으면 하위 맵을 사용, 없으면 최상위 json을 직접 사용
    final jvmInfo = json['jvm_info'] as Map<String, dynamic>? ?? json;
    // gc_info 하위 맵 추출, 없으면 빈 맵 사용
    final gcMap = jvmInfo['gc_info'] as Map<String, dynamic>? ?? {};
    return JvmMetrics(
      // timestamp: 밀리초 에포크 타임을 DateTime으로 변환
      timestamp: DateTime.fromMillisecondsSinceEpoch(
          (json['timestamp'] as num?)?.toInt() ?? 0),
      // heap_used: num 타입 안전하게 int로 변환, null이면 0
      heapUsed: (jvmInfo['heap_used'] as num?)?.toInt() ?? 0,
      // heap_max: null이면 0 대신 1 (나누기 0 방지)
      heapMax: (jvmInfo['heap_max'] as num?)?.toInt() ?? 1,
      // heap_used_percent: double로 변환
      heapUsedPercent: (jvmInfo['heap_used_percent'] as num?)?.toDouble() ?? 0,
      // non_heap_used: int로 변환
      nonHeapUsed: (jvmInfo['non_heap_used'] as num?)?.toInt() ?? 0,
      // thread_count: 전체 스레드 수
      threadCount: (jvmInfo['thread_count'] as num?)?.toInt() ?? 0,
      // running_count: RUNNABLE 상태 스레드 수
      runningCount: (jvmInfo['running_count'] as num?)?.toInt() ?? 0,
      // waiting_count: WAITING 상태 스레드 수
      waitingCount: (jvmInfo['waiting_count'] as num?)?.toInt() ?? 0,
      // blocked_count: BLOCKED 상태 스레드 수
      blockedCount: (jvmInfo['blocked_count'] as num?)?.toInt() ?? 0,
      // deadlock_count: 데드락 스레드 수
      deadlockCount: (jvmInfo['deadlock_count'] as num?)?.toInt() ?? 0,
      // GcInfo 객체 생성
      gcInfo: GcInfo.fromJson(gcMap),
    );
  }

  // Heap 사용량을 MB 단위로 변환하는 getter (바이트 → 메가바이트)
  double get heapUsedMb => heapUsed / (1024 * 1024);
  // Heap 최대 크기를 MB 단위로 변환하는 getter
  double get heapMaxMb => heapMax / (1024 * 1024);
}

// GC(가비지 컬렉션) 정보 모델
class GcInfo {
  // 총 GC 발생 횟수
  final int collectionCount;
  // 총 GC 소요 시간 (밀리초)
  final int collectionTimeMs;
  // 마지막 GC 원인 (예: "Allocation Failure")
  final String lastGcCause;

  // 생성자
  GcInfo({
    required this.collectionCount,
    required this.collectionTimeMs,
    required this.lastGcCause,
  });

  // JSON 맵에서 GcInfo 생성하는 팩토리 생성자 (화살표 문법 사용)
  factory GcInfo.fromJson(Map<String, dynamic> json) => GcInfo(
        // GC 횟수 파싱
        collectionCount: (json['collection_count'] as num?)?.toInt() ?? 0,
        // GC 누적 시간 파싱
        collectionTimeMs: (json['collection_time_ms'] as num?)?.toInt() ?? 0,
        // 마지막 GC 원인 파싱, null이면 'N/A'
        lastGcCause: json['last_gc_cause']?.toString() ?? 'N/A',
      );
}

/// Flame Graph 노드: CPU 프로파일링 결과를 트리 구조로 표현
class FlameNode {
  // 메서드의 전체 이름 (패키지 포함)
  final String name;
  // 해당 노드에서 수집된 샘플 수 (CPU 사용 비중을 나타냄)
  final int value;
  // 자기 자신(자식 제외)이 소비한 시간 (밀리초)
  final int selfTimeMs;
  // 자식 노드 목록 (재귀적 트리 구조)
  final List<FlameNode> children;

  // 렌더링용 레이아웃 계산 후 설정되는 위치/크기 변수들
  double x = 0;      // X 좌표 (픽셀)
  double y = 0;      // Y 좌표 (픽셀)
  double width = 0;  // 노드 너비 (픽셀)
  double depth = 0;  // 트리 깊이 레벨

  // 생성자
  FlameNode({
    required this.name,
    required this.value,
    required this.selfTimeMs,
    required this.children,
  });

  // JSON 맵에서 FlameNode 생성 (재귀적으로 자식 노드도 파싱)
  factory FlameNode.fromJson(Map<String, dynamic> json) {
    // 자식 노드 JSON 리스트 추출, 없으면 빈 리스트
    final childrenJson = json['children'] as List<dynamic>? ?? [];
    return FlameNode(
      // 메서드 이름, null이면 'unknown'
      name: json['name']?.toString() ?? 'unknown',
      // 샘플 수
      value: (json['value'] as num?)?.toInt() ?? 0,
      // 자기 자신 소비 시간
      selfTimeMs: (json['self_time_ms'] as num?)?.toInt() ?? 0,
      // 자식 목록: 재귀적으로 FlameNode.fromJson 호출
      children:
          childrenJson.map((c) => FlameNode.fromJson(c as Map<String, dynamic>)).toList(),
    );
  }

  // 짧은 이름 getter: 패키지 경로를 줄여 '클래스.메서드' 형태로 반환
  String get shortName {
    // '.'으로 분리 후 마지막 2개 부분만 사용
    final parts = name.split('.');
    return parts.length > 2 ? '${parts[parts.length - 2]}.${parts.last}' : name;
  }
}

/// SQL 이벤트: 에이전트가 캡처한 개별 SQL 실행 정보
class SqlEvent {
  // SQL 실행 시각
  final DateTime timestamp;
  // 실행된 SQL 문자열
  final String sql;
  // SQL 실행 소요 시간 (밀리초)
  final int executionMs;
  // 슬로우 쿼리 여부 (서버 설정 임계값 초과 시 true)
  final bool isSlowQuery;
  // SQL을 호출한 Java 메서드명
  final String callerMethod;

  // 생성자
  SqlEvent({
    required this.timestamp,
    required this.sql,
    required this.executionMs,
    required this.isSlowQuery,
    required this.callerMethod,
  });

  // JSON에서 SqlEvent 생성하는 팩토리 생성자
  factory SqlEvent.fromJson(Map<String, dynamic> json) => SqlEvent(
        // 밀리초 에포크 → DateTime 변환
        timestamp: DateTime.fromMillisecondsSinceEpoch(
            (json['timestamp'] as num?)?.toInt() ?? 0),
        // SQL 문자열, null이면 빈 문자열
        sql: json['sql']?.toString() ?? '',
        // 실행 시간 (ms)
        executionMs: (json['execution_ms'] as num?)?.toInt() ?? 0,
        // 슬로우 쿼리 여부
        isSlowQuery: json['is_slow_query'] as bool? ?? false,
        // 호출 메서드명
        callerMethod: json['caller_method']?.toString() ?? '',
      );
}

/// 스레드 정보: JVM 스레드 덤프의 개별 스레드 상태
class ThreadInfo {
  // 스레드 ID
  final int id;
  // 스레드 이름 (예: "http-nio-8080-exec-1")
  final String name;
  // 스레드 상태 (RUNNABLE, BLOCKED, WAITING, TIMED_WAITING 등)
  final String state;
  // 현재 보유/대기 중인 락 이름 (없으면 null)
  final String? lockName;
  // 락을 소유한 다른 스레드의 ID (없으면 null)
  final int? lockOwnerId;
  // 스택 트레이스 목록 (호출 스택 상단부터 순서대로)
  final List<String> stackTrace;

  // 생성자
  ThreadInfo({
    required this.id,
    required this.name,
    required this.state,
    this.lockName,      // 선택적 필드
    this.lockOwnerId,   // 선택적 필드
    required this.stackTrace,
  });

  // JSON에서 ThreadInfo 생성하는 팩토리 생성자
  factory ThreadInfo.fromJson(Map<String, dynamic> json) => ThreadInfo(
        // 스레드 ID
        id: (json['id'] as num?)?.toInt() ?? 0,
        // 스레드 이름
        name: json['name']?.toString() ?? '',
        // 스레드 상태 문자열, null이면 'UNKNOWN'
        state: json['state']?.toString() ?? 'UNKNOWN',
        // 락 이름 (선택)
        lockName: json['lock_name']?.toString(),
        // 락 소유 스레드 ID (선택)
        lockOwnerId: (json['lock_owner_id'] as num?)?.toInt(),
        // 스택 트레이스: 리스트를 String으로 변환, null이면 빈 리스트
        stackTrace: (json['stack_trace'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );

  // BLOCKED 상태 여부를 반환하는 편의 getter
  bool get isBlocked => state == 'BLOCKED';
  // RUNNABLE 상태 여부를 반환하는 편의 getter
  bool get isRunning => state == 'RUNNABLE';
}

/// 프로파일러 알림: 이상 감지 시 백엔드에서 Push하는 경보 정보
class ProfilerAlert {
  // 알림 유형 (예: 'HIGH_HEAP_ALERT', 'DEADLOCK_ALERT', 'SLOW_SQL_ALERT')
  final String type;
  // 사용자에게 표시할 알림 메시지
  final String message;
  // 알림 발생 시각
  final DateTime timestamp;

  // 생성자
  ProfilerAlert({
    required this.type,
    required this.message,
    required this.timestamp,
  });
}
