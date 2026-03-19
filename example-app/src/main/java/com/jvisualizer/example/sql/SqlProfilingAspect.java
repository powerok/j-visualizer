package com.jvisualizer.example.sql;

import lombok.extern.slf4j.Slf4j;
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.List;

/**
 * Repository 메서드 실행 시 SqlCapture를 통해 실제 SQL을 캡처하고 Backend로 전송
 */
@Aspect
@Component
@Slf4j
public class SqlProfilingAspect {

    @Value("${jvisualizer.backend-url:http://localhost:8080}")
    private String backendUrl;

    @Value("${jvisualizer.slow-sql-threshold-ms:100}")
    private long slowSqlThreshold;

    private static final HttpClient HTTP_CLIENT = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(3))
            .build();

    @Around("execution(* com.jvisualizer.example.repository.*.*(..))")
    public Object profileRepository(ProceedingJoinPoint pjp) throws Throwable {
        String callerMethod = pjp.getSignature().getDeclaringTypeName()
                + "." + pjp.getSignature().getName() + "()";

        // SQL 캡처 시작
        SqlCapture.start();
        long start = System.currentTimeMillis();
        Object result;
        try {
            result = pjp.proceed();
        } finally {
            long elapsed = System.currentTimeMillis() - start;
            List<SqlCapture.CapturedSql> sqls = SqlCapture.stop();

            if (!sqls.isEmpty()) {
                // 캡처된 SQL 각각을 이벤트로 전송
                for (SqlCapture.CapturedSql captured : sqls) {
                    boolean isSlow = elapsed >= slowSqlThreshold;
                    if (isSlow) {
                        log.warn("[SlowSQL] {}ms | {} | {}", elapsed, callerMethod,
                                captured.sql().length() > 80
                                        ? captured.sql().substring(0, 80) + "..." : captured.sql());
                    }
                    sendSqlEvent(captured.sql(), callerMethod, elapsed, isSlow);
                }
            } else {
                // SQL이 캡처 안 된 경우(캐시 히트 등) 메서드명만 전송
                boolean isSlow = elapsed >= slowSqlThreshold;
                sendSqlEvent("/* (cached or no-sql) " + callerMethod + " */",
                        callerMethod, elapsed, isSlow);
            }
        }
        return result;
    }

    private void sendSqlEvent(String sql, String callerMethod, long elapsedMs, boolean isSlow) {
        String payload = String.format(
            "{\"type\":\"SQL_EVENT\",\"timestamp\":%d,\"sql\":%s," +
            "\"execution_ms\":%d,\"is_slow_query\":%b," +
            "\"caller_method\":%s,\"app_name\":\"j-visualizer-example\"}",
            System.currentTimeMillis(),
            toJsonString(sql),
            elapsedMs,
            isSlow,
            toJsonString(callerMethod)
        );

        try {
            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(backendUrl + "/api/sql"))
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(payload))
                    .timeout(Duration.ofSeconds(5))
                    .build();
            HTTP_CLIENT.sendAsync(request, HttpResponse.BodyHandlers.discarding())
                    .exceptionally(ex -> {
                        log.debug("SQL send failed: {}", ex.getMessage());
                        return null;
                    });
        } catch (Exception e) {
            log.debug("SQL send error: {}", e.getMessage());
        }
    }

    private String toJsonString(String val) {
        if (val == null) return "null";
        return "\"" + val.replace("\\", "\\\\")
                         .replace("\"", "\\\"")
                         .replace("\n", " ")
                         .replace("\r", "") + "\"";
    }
}