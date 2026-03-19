package com.jvisualizer.agent;

import com.jvisualizer.agent.cpu.CpuProfiler;
import com.jvisualizer.agent.memory.MemoryProfiler;
import com.jvisualizer.agent.sql.SqlProfiler;
import com.jvisualizer.agent.thread.ThreadProfiler;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.lang.instrument.Instrumentation;

/**
 * J-Visualizer Java Agent 진입점
 *
 * 실행 예시:
 *   java -javaagent:j-visualizer-agent.jar=server=http://localhost:8080,mode=sampling,interval=10,package=com.example
 *        -jar myapp.jar
 */
public class AgentMain {

    private static final Logger log = LoggerFactory.getLogger(AgentMain.class);

    /**
     * JVM 시작 시 호출 (static attach)
     */
    public static void premain(String agentArgs, Instrumentation instrumentation) {
        log.info("========================================");
        log.info("  J-Visualizer Agent Starting (premain)");
        log.info("========================================");
        init(agentArgs, instrumentation);
    }

    /**
     * 실행 중인 JVM에 동적으로 attach 시 호출
     */
    public static void agentmain(String agentArgs, Instrumentation instrumentation) {
        log.info("==========================================");
        log.info("  J-Visualizer Agent Starting (agentmain)");
        log.info("==========================================");
        init(agentArgs, instrumentation);
    }

    private static void init(String agentArgs, Instrumentation instrumentation) {
        try {
            AgentConfig config = AgentConfig.parse(agentArgs);
            log.info("Agent Config: {}", config);

            ProfilingOrchestrator orchestrator = new ProfilingOrchestrator(config, instrumentation);
            orchestrator.start();

            // JVM 종료 시 graceful shutdown
            Runtime.getRuntime().addShutdownHook(new Thread(() -> {
                log.info("J-Visualizer Agent shutting down...");
                orchestrator.stop();
            }, "j-visualizer-shutdown"));

        } catch (Exception e) {
            log.error("Failed to initialize J-Visualizer Agent", e);
        }
    }
}
