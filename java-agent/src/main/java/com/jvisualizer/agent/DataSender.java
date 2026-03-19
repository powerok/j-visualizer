package com.jvisualizer.agent;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.jvisualizer.agent.cpu.CpuProfiler;
import com.jvisualizer.agent.memory.MemoryProfiler;
import com.jvisualizer.agent.sql.SqlProfiler;
import com.jvisualizer.agent.thread.ThreadProfiler;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * 수집된 프로파일링 데이터를 Backend 서버로 전송하는 컴포넌트
 *
 * HTTP POST를 사용하여 Backend REST API로 전송합니다.
 * WebSocket 연결 실패 시 HTTP fallback을 사용합니다.
 */
public class DataSender {

    private static final Logger log = LoggerFactory.getLogger(DataSender.class);

    private final AgentConfig config;
    private final ObjectMapper objectMapper;
    private final HttpClient httpClient;

    public DataSender(AgentConfig config) {
        this.config = config;
        this.objectMapper = new ObjectMapper();
        this.httpClient = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(5))
                .build();
    }

    public void connect() {
        log.info("DataSender initialized. Target server: {}", config.getServerUrl());
        // WebSocket 연결 초기화 (실제 구현에서는 Java-WebSocket 라이브러리 사용)
        sendAgentRegistration();
    }

    public void disconnect() {
        log.info("DataSender disconnecting...");
    }

    /**
     * Agent 등록 신호 전송
     */
    private void sendAgentRegistration() {
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("type", "AGENT_CONNECTED");
        payload.put("timestamp", System.currentTimeMillis());
        payload.put("app_name", System.getProperty("sun.java.command", "unknown"));
        payload.put("jvm_version", System.getProperty("java.version"));
        payload.put("pid", ProcessHandle.current().pid());
        payload.put("profiling_mode", config.getMode().name());

        postAsync(config.getServerUrl() + "/api/agent/register", payload);
    }

    /**
     * 실시간 JVM 메트릭 전송 (1초 간격)
     */
    public void sendMetrics(MemoryProfiler.HeapInfo heapInfo,
                            MemoryProfiler.GcInfo gcInfo,
                            ThreadProfiler.ThreadStats threadStats) {
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("type", "METRICS");
        payload.put("timestamp", System.currentTimeMillis());

        Map<String, Object> jvmInfo = new LinkedHashMap<>();
        jvmInfo.putAll(heapInfo.toMap());
        jvmInfo.putAll(threadStats.toMap());
        jvmInfo.put("gc_info", gcInfo.toMap());
        payload.put("jvm_info", jvmInfo);

        postAsync(config.getServerUrl() + "/api/metrics", payload);
    }

    /**
     * CPU Flame Graph 데이터 전송
     */
    public void sendCpuProfile(CpuProfiler.FlameGraphData profileData) {
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("timestamp", profileData.timestamp());
        payload.put("duration_ms", profileData.durationMs());
        payload.put("total_samples", profileData.totalSamples());
        payload.put("profile_type", profileData.profileType());
        payload.put("data", profileData.data());

        postAsync(config.getServerUrl() + "/api/profile", payload);
    }

    /**
     * Thread Dump 전송
     */
    public void sendThreadDump(ThreadProfiler.ThreadDumpData threadDump) {
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("type", "THREAD_DUMP");
        payload.put("timestamp", threadDump.timestamp());
        payload.put("threads", threadDump.threads());
        payload.put("deadlocked_thread_ids", threadDump.deadlockedThreadIds());

        postAsync(config.getServerUrl() + "/api/threads", payload);
    }

    /**
     * SQL 이벤트 전송 (즉시)
     */
    public void sendSqlEvent(SqlProfiler.SqlEvent sqlEvent) {
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("type", "SQL_EVENT");
        payload.putAll(sqlEvent.toMap());

        postAsync(config.getServerUrl() + "/api/sql", payload);
    }

    /**
     * 비동기 HTTP POST 전송
     */
    private void postAsync(String url, Map<String, Object> payload) {
        try {
            String json = objectMapper.writeValueAsString(payload);
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .header("Content-Type", "application/json")
                    .header("X-Agent-Version", "1.0.0")
                    .POST(HttpRequest.BodyPublishers.ofString(json))
                    .timeout(Duration.ofSeconds(10))
                    .build();

            httpClient.sendAsync(request, HttpResponse.BodyHandlers.ofString())
                    .thenAccept(response -> {
                        if (response.statusCode() >= 400) {
                            log.warn("Server returned error {}: {}", response.statusCode(), url);
                        }
                    })
                    .exceptionally(ex -> {
                        log.debug("Failed to send data to {}: {}", url, ex.getMessage());
                        return null;
                    });
        } catch (Exception e) {
            log.debug("Error serializing payload for {}: {}", url, e.getMessage());
        }
    }
}
