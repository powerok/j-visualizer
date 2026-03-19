package com.jvisualizer.backend.controller;

import com.jvisualizer.backend.dto.BottleneckReportDto;
import com.jvisualizer.backend.dto.SqlSummaryDto;
import com.jvisualizer.backend.model.CpuProfile;
import com.jvisualizer.backend.model.JvmMetrics;
import com.jvisualizer.backend.model.ThreadSnapshot;
import com.jvisualizer.backend.service.ProfilingDataService;
import com.jvisualizer.backend.websocket.ProfilerWebSocketHandler;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/**
 * Agent → Backend 데이터 수신 및 Frontend 조회 API
 */
@RestController
@RequestMapping("/api")
@RequiredArgsConstructor
@Slf4j
@CrossOrigin(origins = "*")
public class ProfilerController {

    private final ProfilingDataService service;
    private final ProfilerWebSocketHandler wsHandler;

    // ────────────────────────────────────────────────
    // Agent 등록
    // ────────────────────────────────────────────────

    @PostMapping("/agent/register")
    public ResponseEntity<Map<String, Object>> registerAgent(@RequestBody Map<String, Object> payload) {
        log.info("Agent registered: appName={}, pid={}, jvm={}",
                payload.get("app_name"), payload.get("pid"), payload.get("jvm_version"));
        wsHandler.broadcast("AGENT_CONNECTED", payload);
        return ResponseEntity.ok(Map.of("status", "registered", "serverTime", System.currentTimeMillis()));
    }

    // ────────────────────────────────────────────────
    // 데이터 수신 (Agent → Backend)
    // ────────────────────────────────────────────────

    @PostMapping("/metrics")
    public ResponseEntity<Void> receiveMetrics(@RequestBody Map<String, Object> payload) {
        service.saveMetrics(payload);
        return ResponseEntity.accepted().build();
    }

    @PostMapping("/profile")
    public ResponseEntity<Void> receiveCpuProfile(@RequestBody Map<String, Object> payload) {
        service.saveCpuProfile(payload);
        return ResponseEntity.accepted().build();
    }

    @PostMapping("/threads")
    public ResponseEntity<Void> receiveThreadDump(@RequestBody Map<String, Object> payload) {
        service.saveThreadDump(payload);
        return ResponseEntity.accepted().build();
    }

    @PostMapping("/sql")
    public ResponseEntity<Void> receiveSqlEvent(@RequestBody Map<String, Object> payload) {
        service.saveSqlEvent(payload);
        return ResponseEntity.accepted().build();
    }

    // ────────────────────────────────────────────────
    // 조회 (Frontend → Backend)
    // ────────────────────────────────────────────────

    @GetMapping("/metrics/history")
    public ResponseEntity<List<JvmMetrics>> getMetricsHistory(
            @RequestParam(defaultValue = "10") int minutes) {
        return ResponseEntity.ok(service.getRecentMetrics(minutes));
    }

    @GetMapping("/profile/latest")
    public ResponseEntity<?> getLatestProfile() {
        return service.getLatestProfile()
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.noContent().build());
    }

    @GetMapping("/profile/history")
    public ResponseEntity<List<CpuProfile>> getProfileHistory() {
        return ResponseEntity.ok(service.getRecentProfiles());
    }

    @GetMapping("/threads/latest")
    public ResponseEntity<?> getLatestThreadDump() {
        return service.getLatestThreadDump()
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.noContent().build());
    }

    @GetMapping("/sql/events")
    public ResponseEntity<?> getRecentSqlEvents() {
        return ResponseEntity.ok(service.getRecentSqlEvents());
    }

    @GetMapping("/sql/stats")
    public ResponseEntity<SqlSummaryDto> getSqlStats() {
        return ResponseEntity.ok(service.getSqlSummary());
    }

    @GetMapping("/bottlenecks")
    public ResponseEntity<BottleneckReportDto> getBottlenecks() {
        return ResponseEntity.ok(service.analyzeBottlenecks());
    }

    // ────────────────────────────────────────────────
    // 상태 확인
    // ────────────────────────────────────────────────

    @GetMapping("/status")
    public ResponseEntity<Map<String, Object>> getStatus() {
        return ResponseEntity.ok(Map.of(
                "status", "running",
                "connectedDashboards", wsHandler.getDashboardCount(),
                "connectedAgents", wsHandler.getAgentCount(),
                "serverTime", System.currentTimeMillis()
        ));
    }
}
