package com.jvisualizer.example;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * J-Visualizer Java Agent 테스트용 예제 애플리케이션
 *
 * 실행 방법:
 *   java -javaagent:../java-agent/target/j-visualizer-agent.jar \
 *        =server=http://localhost:8080,mode=sampling,interval=10,package=com.jvisualizer.example \
 *        -jar target/j-visualizer-example.jar
 *
 * 제공하는 테스트 시나리오:
 *   GET /test/cpu-intensive   - CPU 부하 (Flame Graph 데이터 생성)
 *   GET /test/memory-leak     - 메모리 누수 시뮬레이션
 *   GET /test/slow-sql        - Slow SQL 시뮬레이션
 *   GET /test/thread-contention - Thread BLOCKED 시뮬레이션
 *   GET /test/deadlock        - Deadlock 시뮬레이션
 *   GET /test/full-load       - 복합 부하 테스트
 */
@SpringBootApplication
@EnableScheduling
public class ExampleApplication {
    public static void main(String[] args) {
        SpringApplication.run(ExampleApplication.class, args);
    }
}
