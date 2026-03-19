package com.jvisualizer.agent;

import com.jvisualizer.agent.cpu.CpuProfiler;
import com.jvisualizer.agent.memory.MemoryProfiler;
import com.jvisualizer.agent.sql.SqlProfiler;
import com.jvisualizer.agent.thread.ThreadProfiler;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.lang.instrument.Instrumentation;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

/**
 * 모든 프로파일러를 조율하고 데이터 전송을 스케줄링하는 오케스트레이터
 */
public class ProfilingOrchestrator {

    private static final Logger log = LoggerFactory.getLogger(ProfilingOrchestrator.class);

    private final AgentConfig config;
    private final Instrumentation instrumentation;

    private final CpuProfiler cpuProfiler;
    private final MemoryProfiler memoryProfiler;
    private final ThreadProfiler threadProfiler;
    private final SqlProfiler sqlProfiler;
    private final DataSender dataSender;

    private final ScheduledExecutorService scheduler;

    public ProfilingOrchestrator(AgentConfig config, Instrumentation instrumentation) {
        this.config = config;
        this.instrumentation = instrumentation;
        this.dataSender = new DataSender(config);
        this.cpuProfiler = new CpuProfiler(config, dataSender);
        this.memoryProfiler = new MemoryProfiler(dataSender);
        this.threadProfiler = new ThreadProfiler(dataSender);
        this.sqlProfiler = new SqlProfiler(config, instrumentation, dataSender);
        this.scheduler = Executors.newScheduledThreadPool(4,
                r -> new Thread(r, "j-visualizer-scheduler"));
    }

    public void start() {
        log.info("Starting profiling orchestrator...");

        // DataSender WebSocket 연결
        dataSender.connect();

        // 1. 실시간 메트릭 (1초 간격) - Memory + Thread 상태
        scheduler.scheduleAtFixedRate(this::collectAndSendMetrics,
                1, 1, TimeUnit.SECONDS);

        // 2. CPU 프로파일링 데이터 flush (flushInterval 간격)
        if (config.getMode() == AgentConfig.ProfilingMode.SAMPLING) {
            cpuProfiler.startSampling(config.getSamplingIntervalMs());
            scheduler.scheduleAtFixedRate(this::flushCpuProfile,
                    config.getFlushIntervalMs(), config.getFlushIntervalMs(), TimeUnit.MILLISECONDS);
        }

        // 3. Thread Dump (30초 간격)
        scheduler.scheduleAtFixedRate(this::collectAndSendThreadDump,
                5, 30, TimeUnit.SECONDS);

        // 4. SQL Profiling (Instrumentation 기반)
        if (config.isSqlProfilingEnabled()) {
            sqlProfiler.instrument();
        }

        log.info("Profiling orchestrator started successfully.");
    }

    private void collectAndSendMetrics() {
        try {
            var heapInfo = memoryProfiler.getHeapUsage();
            var gcInfo = memoryProfiler.getGcInfo();
            var threadStats = threadProfiler.getThreadStats();
            dataSender.sendMetrics(heapInfo, gcInfo, threadStats);
        } catch (Exception e) {
            log.warn("Failed to collect metrics: {}", e.getMessage());
        }
    }

    private void flushCpuProfile() {
        try {
            var profileData = cpuProfiler.buildFlameGraph();
            if (profileData != null) {
                dataSender.sendCpuProfile(profileData);
            }
        } catch (Exception e) {
            log.warn("Failed to flush CPU profile: {}", e.getMessage());
        }
    }

    private void collectAndSendThreadDump() {
        try {
            var threadDump = threadProfiler.getThreadDump();
            dataSender.sendThreadDump(threadDump);
        } catch (Exception e) {
            log.warn("Failed to collect thread dump: {}", e.getMessage());
        }
    }

    public void stop() {
        log.info("Stopping profiling orchestrator...");
        scheduler.shutdown();
        try {
            if (!scheduler.awaitTermination(5, TimeUnit.SECONDS)) {
                scheduler.shutdownNow();
            }
        } catch (InterruptedException e) {
            scheduler.shutdownNow();
            Thread.currentThread().interrupt();
        }

        cpuProfiler.stopSampling();
        dataSender.disconnect();
        log.info("Profiling orchestrator stopped.");
    }
}
