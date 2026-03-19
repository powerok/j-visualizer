// lib/models/profiler_models.dart

/// JVM 실시간 메트릭 모델
class JvmMetrics {
  final DateTime timestamp;
  final int heapUsed;
  final int heapMax;
  final double heapUsedPercent;
  final int nonHeapUsed;
  final int threadCount;
  final int runningCount;
  final int waitingCount;
  final int blockedCount;
  final int deadlockCount;
  final GcInfo gcInfo;

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

  factory JvmMetrics.fromJson(Map<String, dynamic> json) {
    final jvmInfo = json['jvm_info'] as Map<String, dynamic>? ?? json;
    final gcMap = jvmInfo['gc_info'] as Map<String, dynamic>? ?? {};
    return JvmMetrics(
      timestamp: DateTime.fromMillisecondsSinceEpoch(
          (json['timestamp'] as num?)?.toInt() ?? 0),
      heapUsed: (jvmInfo['heap_used'] as num?)?.toInt() ?? 0,
      heapMax: (jvmInfo['heap_max'] as num?)?.toInt() ?? 1,
      heapUsedPercent: (jvmInfo['heap_used_percent'] as num?)?.toDouble() ?? 0,
      nonHeapUsed: (jvmInfo['non_heap_used'] as num?)?.toInt() ?? 0,
      threadCount: (jvmInfo['thread_count'] as num?)?.toInt() ?? 0,
      runningCount: (jvmInfo['running_count'] as num?)?.toInt() ?? 0,
      waitingCount: (jvmInfo['waiting_count'] as num?)?.toInt() ?? 0,
      blockedCount: (jvmInfo['blocked_count'] as num?)?.toInt() ?? 0,
      deadlockCount: (jvmInfo['deadlock_count'] as num?)?.toInt() ?? 0,
      gcInfo: GcInfo.fromJson(gcMap),
    );
  }

  double get heapUsedMb => heapUsed / (1024 * 1024);
  double get heapMaxMb => heapMax / (1024 * 1024);
}

class GcInfo {
  final int collectionCount;
  final int collectionTimeMs;
  final String lastGcCause;

  GcInfo({
    required this.collectionCount,
    required this.collectionTimeMs,
    required this.lastGcCause,
  });

  factory GcInfo.fromJson(Map<String, dynamic> json) => GcInfo(
        collectionCount: (json['collection_count'] as num?)?.toInt() ?? 0,
        collectionTimeMs: (json['collection_time_ms'] as num?)?.toInt() ?? 0,
        lastGcCause: json['last_gc_cause']?.toString() ?? 'N/A',
      );
}

/// Flame Graph 노드
class FlameNode {
  final String name;
  final int value;
  final int selfTimeMs;
  final List<FlameNode> children;

  // 렌더링용 (레이아웃 계산 후 설정)
  double x = 0;
  double y = 0;
  double width = 0;
  double depth = 0;

  FlameNode({
    required this.name,
    required this.value,
    required this.selfTimeMs,
    required this.children,
  });

  factory FlameNode.fromJson(Map<String, dynamic> json) {
    final childrenJson = json['children'] as List<dynamic>? ?? [];
    return FlameNode(
      name: json['name']?.toString() ?? 'unknown',
      value: (json['value'] as num?)?.toInt() ?? 0,
      selfTimeMs: (json['self_time_ms'] as num?)?.toInt() ?? 0,
      children:
          childrenJson.map((c) => FlameNode.fromJson(c as Map<String, dynamic>)).toList(),
    );
  }

  String get shortName {
    final parts = name.split('.');
    return parts.length > 2 ? '${parts[parts.length - 2]}.${parts.last}' : name;
  }
}

/// SQL 이벤트
class SqlEvent {
  final DateTime timestamp;
  final String sql;
  final int executionMs;
  final bool isSlowQuery;
  final String callerMethod;

  SqlEvent({
    required this.timestamp,
    required this.sql,
    required this.executionMs,
    required this.isSlowQuery,
    required this.callerMethod,
  });

  factory SqlEvent.fromJson(Map<String, dynamic> json) => SqlEvent(
        timestamp: DateTime.fromMillisecondsSinceEpoch(
            (json['timestamp'] as num?)?.toInt() ?? 0),
        sql: json['sql']?.toString() ?? '',
        executionMs: (json['execution_ms'] as num?)?.toInt() ?? 0,
        isSlowQuery: json['is_slow_query'] as bool? ?? false,
        callerMethod: json['caller_method']?.toString() ?? '',
      );
}

/// 스레드 정보
class ThreadInfo {
  final int id;
  final String name;
  final String state;
  final String? lockName;
  final int? lockOwnerId;
  final List<String> stackTrace;

  ThreadInfo({
    required this.id,
    required this.name,
    required this.state,
    this.lockName,
    this.lockOwnerId,
    required this.stackTrace,
  });

  factory ThreadInfo.fromJson(Map<String, dynamic> json) => ThreadInfo(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name']?.toString() ?? '',
        state: json['state']?.toString() ?? 'UNKNOWN',
        lockName: json['lock_name']?.toString(),
        lockOwnerId: (json['lock_owner_id'] as num?)?.toInt(),
        stackTrace: (json['stack_trace'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );

  bool get isBlocked => state == 'BLOCKED';
  bool get isRunning => state == 'RUNNABLE';
}

/// 알림
class ProfilerAlert {
  final String type;
  final String message;
  final DateTime timestamp;

  ProfilerAlert({
    required this.type,
    required this.message,
    required this.timestamp,
  });
}
