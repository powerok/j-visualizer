package com.jvisualizer.backend.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.jvisualizer.backend.dto.*;
import com.jvisualizer.backend.model.*;
import com.jvisualizer.backend.repository.*;
import com.jvisualizer.backend.websocket.ProfilerWebSocketHandler;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class ProfilingDataService {

    private final JvmMetricsRepository metricsRepo;
    private final CpuProfileRepository profileRepo;
    private final SqlEventRepository sqlRepo;
    private final ThreadSnapshotRepository threadRepo;
    private final ProfilerWebSocketHandler wsHandler;
    private final ObjectMapper objectMapper;

    @Value("${jvisualizer.metrics-retention-minutes:60}")
    private int metricsRetentionMinutes;

    @Value("${jvisualizer.slow-sql-threshold-ms:1000}")
    private long slowSqlThreshold;

    // ────────────────────────────────────────────────
    // 수신 (Agent → Backend)
    // ────────────────────────────────────────────────

    @Transactional
    public void saveMetrics(Map<String, Object> payload) {
        Map<String, Object> jvmInfo = getMap(payload, "jvm_info");

        JvmMetrics metrics = JvmMetrics.builder()
                .timestamp(Instant.ofEpochMilli(toLong(payload.get("timestamp"))))
                .heapUsed(toLong(jvmInfo.get("heap_used")))
                .heapMax(toLong(jvmInfo.get("heap_max")))
                .heapCommitted(toLong(jvmInfo.get("heap_committed")))
                .nonHeapUsed(toLong(jvmInfo.get("non_heap_used")))
                .heapUsedPercent(toDouble(jvmInfo.get("heap_used_percent")))
                .threadCount(toInt(jvmInfo.get("thread_count")))
                .runningCount(toInt(jvmInfo.get("running_count")))
                .waitingCount(toInt(jvmInfo.get("waiting_count")))
                .blockedCount(toInt(jvmInfo.get("blocked_count")))
                .deadlockCount(toInt(jvmInfo.get("deadlock_count")))
                .gcCollectionCount(toLong(getNestedValue(jvmInfo, "gc_info", "collection_count")))
                .gcCollectionTimeMs(toLong(getNestedValue(jvmInfo, "gc_info", "collection_time_ms")))
                .lastGcCause(String.valueOf(getNestedValue(jvmInfo, "gc_info", "last_gc_cause")))
                .appName(String.valueOf(payload.getOrDefault("app_name", "unknown")))
                .build();

        metricsRepo.save(metrics);

        // WebSocket broadcast
        wsHandler.broadcast("METRICS", payload);

        // 이상 감지 체크
        checkAlerts(metrics);
    }

    @Transactional
    public void saveCpuProfile(Map<String, Object> payload) {
        try {
            String json = objectMapper.writeValueAsString(payload.get("data"));
            CpuProfile profile = CpuProfile.builder()
                    .timestamp(Instant.ofEpochMilli(toLong(payload.get("timestamp"))))
                    .durationMs(toLong(payload.get("duration_ms")))
                    .totalSamples(toInt(payload.get("total_samples")))
                    .profileType(String.valueOf(payload.getOrDefault("profile_type", "CPU_SAMPLING")))
                    .flameGraphJson(json)
                    .appName(String.valueOf(payload.getOrDefault("app_name", "unknown")))
                    .build();

            profileRepo.save(profile);
            wsHandler.broadcast("CPU_PROFILE", payload);
            log.debug("Saved CPU profile: {} samples over {}ms", profile.getTotalSamples(), profile.getDurationMs());
        } catch (Exception e) {
            log.error("Failed to save CPU profile", e);
        }
    }

    @Transactional
    public void saveThreadDump(Map<String, Object> payload) {
        try {
            Object threads = payload.get("threads");
            String json = objectMapper.writeValueAsString(threads);

            int total = toInt(payload.getOrDefault("total_count", 0));

            ThreadSnapshot snapshot = ThreadSnapshot.builder()
                    .timestamp(Instant.ofEpochMilli(toLong(payload.get("timestamp"))))
                    .threadDumpJson(json)
                    .appName(String.valueOf(payload.getOrDefault("app_name", "unknown")))
                    .build();

            threadRepo.save(snapshot);
            wsHandler.broadcast("THREAD_DUMP", payload);
        } catch (Exception e) {
            log.error("Failed to save thread dump", e);
        }
    }

    @Transactional
    public void saveSqlEvent(Map<String, Object> payload) {
        long execMs = toLong(payload.get("execution_ms"));
        boolean isSlow = execMs >= slowSqlThreshold;

        SqlEvent event = SqlEvent.builder()
                .timestamp(Instant.ofEpochMilli(toLong(payload.get("timestamp"))))
                .sql(String.valueOf(payload.getOrDefault("sql", "")))
                .executionMs(execMs)
                .slowQuery(isSlow)
                .callerMethod(String.valueOf(payload.getOrDefault("caller_method", "")))
                .appName(String.valueOf(payload.getOrDefault("app_name", "unknown")))
                .build();

        sqlRepo.save(event);
        wsHandler.broadcast("SQL_EVENT", payload);

        if (isSlow) {
            Map<String, Object> alert = Map.of(
                    "type", "SLOW_SQL_ALERT",
                    "sql", event.getSql(),
                    "execution_ms", execMs,
                    "timestamp", event.getTimestamp().toEpochMilli()
            );
            wsHandler.broadcast("ALERT", alert);
        }
    }

    // ────────────────────────────────────────────────
    // 조회
    // ────────────────────────────────────────────────

    public List<JvmMetrics> getRecentMetrics(int minutes) {
        Instant since = Instant.now().minusSeconds((long) minutes * 60);
        return metricsRepo.findMetricsSince(since);
    }

    public Optional<CpuProfile> getLatestProfile() {
        return profileRepo.findTopByOrderByTimestampDesc();
    }

    public List<CpuProfile> getRecentProfiles() {
        return profileRepo.findTop10ByOrderByTimestampDesc();
    }

    public Optional<ThreadSnapshot> getLatestThreadDump() {
        return threadRepo.findTopByOrderByTimestampDesc();
    }

    public List<SqlEvent> getRecentSqlEvents() {
        return sqlRepo.findTop100ByOrderByTimestampDesc();
    }

    public SqlSummaryDto getSqlSummary() {
        long total = sqlRepo.count();
        long slow = sqlRepo.countBySlowQueryTrue();
        List<SqlEvent> slowest = sqlRepo.findSlowest20();
        return new SqlSummaryDto(total, slow, slowest);
    }

    public BottleneckReportDto analyzeBottlenecks() {
        List<String> issues = new ArrayList<>();

        // 최근 메트릭에서 이상 감지
        List<JvmMetrics> recent = metricsRepo.findTop60ByOrderByTimestampDesc();
        if (!recent.isEmpty()) {
            double avgHeap = recent.stream().mapToDouble(JvmMetrics::getHeapUsedPercent).average().orElse(0);
            double avgBlocked = recent.stream().mapToDouble(JvmMetrics::getBlockedCount).average().orElse(0);
            long totalDeadlocks = recent.stream().mapToLong(JvmMetrics::getDeadlockCount).sum();

            if (avgHeap > 85) issues.add(String.format("⚠️ 높은 Heap 사용률: 평균 %.1f%%", avgHeap));
            if (avgBlocked > 5) issues.add(String.format("⚠️ BLOCKED 스레드 多: 평균 %.1f개", avgBlocked));
            if (totalDeadlocks > 0) issues.add(String.format("🚨 Deadlock 감지: %d건", totalDeadlocks));
        }

        // Slow SQL 감지
        long slowSqlCount = sqlRepo.countBySlowQueryTrue();
        if (slowSqlCount > 0) {
            issues.add(String.format("⚠️ Slow SQL %d건 감지", slowSqlCount));
        }

        return new BottleneckReportDto(Instant.now(), issues, recent.size());
    }

    // ────────────────────────────────────────────────
    // 이상 감지 / 알림
    // ────────────────────────────────────────────────

    private void checkAlerts(JvmMetrics metrics) {
        // Heap 90% 초과
        if (metrics.getHeapUsedPercent() > 90) {
            wsHandler.broadcast("ALERT", Map.of(
                    "type", "HIGH_HEAP_ALERT",
                    "heap_percent", metrics.getHeapUsedPercent(),
                    "message", String.format("Heap 사용률 %.1f%% - GC 압박 주의", metrics.getHeapUsedPercent())
            ));
        }
        // Deadlock 감지
        if (metrics.getDeadlockCount() > 0) {
            wsHandler.broadcast("ALERT", Map.of(
                    "type", "DEADLOCK_ALERT",
                    "count", metrics.getDeadlockCount(),
                    "message", "Deadlock이 감지되었습니다!"
            ));
        }
    }

    // ────────────────────────────────────────────────
    // 정기 정리
    // ────────────────────────────────────────────────

    @Scheduled(fixedDelay = 60_000) // 1분마다
    @Transactional
    public void cleanupOldMetrics() {
        Instant cutoff = Instant.now().minusSeconds((long) metricsRetentionMinutes * 60);
        metricsRepo.deleteByTimestampBefore(cutoff);
    }

    // ────────────────────────────────────────────────
    // 유틸 헬퍼
    // ────────────────────────────────────────────────

    @SuppressWarnings("unchecked")
    private Map<String, Object> getMap(Map<String, Object> map, String key) {
        Object val = map.get(key);
        return val instanceof Map ? (Map<String, Object>) val : Collections.emptyMap();
    }

    @SuppressWarnings("unchecked")
    private Object getNestedValue(Map<String, Object> map, String... keys) {
        Object cur = map;
        for (String key : keys) {
            if (cur instanceof Map) cur = ((Map<String, Object>) cur).get(key);
            else return null;
        }
        return cur;
    }

    private long toLong(Object val) {
        if (val == null) return 0L;
        if (val instanceof Number n) return n.longValue();
        try { return Long.parseLong(val.toString()); } catch (Exception e) { return 0L; }
    }

    private int toInt(Object val) { return (int) toLong(val); }

    private double toDouble(Object val) {
        if (val == null) return 0.0;
        if (val instanceof Number n) return n.doubleValue();
        try { return Double.parseDouble(val.toString()); } catch (Exception e) { return 0.0; }
    }
}
