package com.jvisualizer.backend.controller;

import com.jvisualizer.backend.model.InvocationRecord;
import com.jvisualizer.backend.repository.InvocationRecordRepository;
import com.jvisualizer.backend.websocket.ProfilerWebSocketHandler;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/invocations")
@RequiredArgsConstructor
@Slf4j
@CrossOrigin(origins = "*")
public class InvocationController {

    private final InvocationRecordRepository repo;
    private final ProfilerWebSocketHandler wsHandler;
    private final com.fasterxml.jackson.databind.ObjectMapper objectMapper;

    /** example-app TrackFilter → Backend 저장 */
    @PostMapping
    public ResponseEntity<Void> receive(@RequestBody Map<String, Object> payload) {
        try {
            // tree 필드는 Map이므로 Jackson으로 직렬화
            Object treeObj = payload.get("tree");
            String treeJsonStr = "";
            if (treeObj != null) {
                try {
                    treeJsonStr = objectMapper.writeValueAsString(treeObj);
                } catch (Exception e) {
                    treeJsonStr = treeObj.toString();
                }
            }

            InvocationRecord record = InvocationRecord.builder()
                    .timestamp(Instant.ofEpochMilli(toLong(payload.get("timestamp"))))
                    .endpoint(str(payload.get("endpoint")))
                    .elapsedMs(toLong(payload.get("elapsed_ms")))
                    .httpStatus(toInt(payload.get("status")))
                    .appName(str(payload.getOrDefault("app_name", "unknown")))
                    .treeText(str(payload.get("tree_text")))
                    .treeJson(treeJsonStr)
                    .build();

            repo.save(record);
            log.debug("Invocation saved: {} {}ms", record.getEndpoint(), record.getElapsedMs());

            // Dashboard로 실시간 Push
            wsHandler.broadcast("INVOCATION", payload);
        } catch (Exception e) {
            log.error("Failed to save invocation", e);
        }
        return ResponseEntity.accepted().build();
    }

    /** 목록 조회 */
    @GetMapping
    public ResponseEntity<List<InvocationRecord>> list(
            @RequestParam(required = false) String endpoint) {
        if (endpoint != null && !endpoint.isBlank()) {
            return ResponseEntity.ok(
                    repo.findByEndpointContainingOrderByTimestampDesc(endpoint));
        }
        return ResponseEntity.ok(repo.findTop100ByOrderByTimestampDesc());
    }

    /** 단건 상세 조회 */
    @GetMapping("/{id}")
    public ResponseEntity<InvocationRecord> get(@PathVariable String id) {
        return repo.findById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    /** 전체 삭제 */
    @DeleteMapping
    public ResponseEntity<Void> clear() {
        repo.deleteAll();
        return ResponseEntity.noContent().build();
    }

    private String str(Object v) { return v == null ? "" : v.toString(); }
    private long toLong(Object v) {
        if (v == null) return 0L;
        if (v instanceof Number n) return n.longValue();
        try { return Long.parseLong(v.toString()); } catch (Exception e) { return 0L; }
    }
    private int toInt(Object v) { return (int) toLong(v); }
}