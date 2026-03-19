package com.jvisualizer.example;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * Example App 통합 테스트
 * 각 테스트 시나리오 엔드포인트가 정상 동작하는지 검증합니다.
 */
@SpringBootTest
@AutoConfigureMockMvc
class ExampleApplicationTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void testStatusEndpoint() throws Exception {
        mockMvc.perform(get("/test/status"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("UP"))
                .andExpect(jsonPath("$.jvm_version").exists())
                .andExpect(jsonPath("$.thread_count").isNumber());
    }

    @Test
    void testIndexEndpoint() throws Exception {
        mockMvc.perform(get("/test"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.service").value("J-Visualizer Example App"))
                .andExpect(jsonPath("$.endpoints").exists());
    }

    @Test
    void testCpuIntensive() throws Exception {
        mockMvc.perform(get("/test/cpu-intensive").param("iterations", "100"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.elapsed_ms").isNumber())
                .andExpect(jsonPath("$.iterations").value(100));
    }

    @Test
    void testMemoryLeak() throws Exception {
        mockMvc.perform(get("/test/memory-leak").param("mb", "5"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.allocated_mb").value(5))
                .andExpect(jsonPath("$.jvm_used_mb").isNumber());
    }

    @Test
    void testMemoryRelease() throws Exception {
        // 먼저 할당
        mockMvc.perform(get("/test/memory-leak").param("mb", "5"));
        // 해제
        mockMvc.perform(get("/test/memory-release"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("released"));
    }

    @Test
    void testSlowSql() throws Exception {
        mockMvc.perform(get("/test/slow-sql"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.total_products").isNumber())
                .andExpect(jsonPath("$.elapsed_ms").isNumber());
    }

    @Test
    void testThreadContention() throws Exception {
        mockMvc.perform(get("/test/thread-contention").param("threads", "3"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.thread_count").value(3))
                .andExpect(jsonPath("$.avg_wait_ms").isNumber());
    }

    @Test
    void testDeadlock() throws Exception {
        mockMvc.perform(get("/test/deadlock"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("deadlock_initiated"));
    }
}
