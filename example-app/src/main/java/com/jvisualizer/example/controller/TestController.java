package com.jvisualizer.example.controller;

import com.jvisualizer.example.service.OrderService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/**
 * J-Visualizer 테스트 시나리오 컨트롤러
 *
 * 각 엔드포인트는 특정 성능 문제를 유발하여
 * Agent가 수집 → Backend 저장 → Dashboard 시각화 흐름을 테스트합니다.
 */
@RestController
@RequestMapping("/test")
@RequiredArgsConstructor
@Slf4j
@CrossOrigin(origins = "*")
public class TestController {

    private final OrderService orderService;

    /**
     * 시나리오 1: CPU 집약적 작업
     * Flame Graph에서 computeLayer1 → computeLayer2 → computeLayer3 호출 계층 확인
     */
    @GetMapping("/cpu-intensive")
    public ResponseEntity<Map<String, Object>> cpuIntensive(
            @RequestParam(defaultValue = "1000") int iterations) {
        log.info("[TEST] CPU intensive: iterations={}", iterations);
        return ResponseEntity.ok(orderService.runCpuIntensiveTask(iterations));
    }

    /**
     * 시나리오 2: 메모리 누수 시뮬레이션
     * Dashboard의 Heap 사용량 차트에서 증가 곡선 확인
     */
    @GetMapping("/memory-leak")
    public ResponseEntity<Map<String, Object>> memoryLeak(
            @RequestParam(defaultValue = "20") int mb) {
        log.info("[TEST] Memory leak: {}MB", mb);
        return ResponseEntity.ok(orderService.simulateMemoryLeak(mb));
    }

    @GetMapping("/memory-release")
    public ResponseEntity<Map<String, Object>> memoryRelease() {
        return ResponseEntity.ok(orderService.releaseMemory());
    }

    /**
     * 시나리오 3: Slow SQL 시뮬레이션
     * SQL Profiler에서 N+1 쿼리 및 LIKE 풀스캔 탐지
     */
    @GetMapping("/slow-sql")
    public ResponseEntity<Map<String, Object>> slowSql() {
        log.info("[TEST] Slow SQL test");
        return ResponseEntity.ok(orderService.runSlowSqlTest());
    }

    /**
     * 시나리오 4: Thread Contention
     * Thread Profiler에서 BLOCKED 상태 스레드 확인
     */
    @GetMapping("/thread-contention")
    public ResponseEntity<Map<String, Object>> threadContention(
            @RequestParam(defaultValue = "10") int threads) throws InterruptedException {
        log.info("[TEST] Thread contention: {} threads", threads);
        return ResponseEntity.ok(orderService.simulateThreadContention(threads));
    }

    /**
     * 시나리오 5: Deadlock 시뮬레이션
     * Thread Profiler의 Deadlock 감지 기능 테스트
     */
    @GetMapping("/deadlock")
    public ResponseEntity<Map<String, Object>> deadlock() {
        log.warn("[TEST] Deadlock simulation initiated!");
        return ResponseEntity.ok(orderService.simulateDeadlock());
    }

    /**
     * 시나리오 6: 복합 부하 - 모든 시나리오 동시 실행
     */
    @GetMapping("/full-load")
    public ResponseEntity<Map<String, Object>> fullLoad() throws InterruptedException {
        log.info("[TEST] Full load test started");
        return ResponseEntity.ok(orderService.runFullLoad());
    }

    /**
     * 헬스 체크 + 현재 JVM 상태 확인
     */
    @GetMapping("/status")
    public ResponseEntity<Map<String, Object>> status() {
        Runtime rt = Runtime.getRuntime();
        return ResponseEntity.ok(Map.of(
                "status", "UP",
                "jvm_version", System.getProperty("java.version"),
                "heap_used_mb", (rt.totalMemory() - rt.freeMemory()) / (1024 * 1024),
                "heap_max_mb", rt.maxMemory() / (1024 * 1024),
                "available_processors", rt.availableProcessors(),
                "thread_count", Thread.activeCount(),
                "pid", ProcessHandle.current().pid()
        ));
    }

    /**
     * 사용 가능한 테스트 목록 확인
     */
    @GetMapping
    public ResponseEntity<Map<String, Object>> index() {
        return ResponseEntity.ok(Map.of(
                "service", "J-Visualizer Example App",
                "endpoints", Map.of(
                        "GET /test/status", "JVM 상태 확인",
                        "GET /test/cpu-intensive?iterations=1000", "CPU 집약적 작업 (Flame Graph 테스트)",
                        "GET /test/memory-leak?mb=20", "메모리 누수 시뮬레이션",
                        "GET /test/memory-release", "누수 메모리 해제",
                        "GET /test/slow-sql", "Slow SQL / N+1 쿼리 시뮬레이션",
                        "GET /test/thread-contention?threads=10", "Thread Contention 시뮬레이션",
                        "GET /test/deadlock", "Deadlock 시뮬레이션",
                        "GET /test/full-load", "복합 부하 테스트 (모든 시나리오)"
                )
        ));
    }
}