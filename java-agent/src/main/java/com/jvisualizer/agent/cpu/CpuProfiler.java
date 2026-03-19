package com.jvisualizer.agent.cpu;

import com.jvisualizer.agent.AgentConfig;
import com.jvisualizer.agent.DataSender;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicLong;

/**
 * CPU Profiler - Sampling 방식 구현
 *
 * 설정된 intervalMs마다 모든 스레드의 Stack Trace를 수집하여
 * Flame Graph 데이터 구조로 변환합니다.
 */
public class CpuProfiler {

    private static final Logger log = LoggerFactory.getLogger(CpuProfiler.class);

    private final AgentConfig config;
    private final DataSender dataSender;

    // 샘플링 수집 버퍼
    private final List<StackTrace[]> samples = new CopyOnWriteArrayList<>();
    private final AtomicLong totalSamples = new AtomicLong(0);
    private final AtomicLong startTime = new AtomicLong(0);

    private ScheduledExecutorService samplerExecutor;
    private volatile boolean running = false;

    public CpuProfiler(AgentConfig config, DataSender dataSender) {
        this.config = config;
        this.dataSender = dataSender;
    }

    /**
     * 주기적 샘플링 시작
     */
    public void startSampling(int intervalMs) {
        if (running) return;
        running = true;
        startTime.set(System.currentTimeMillis());
        samplerExecutor = Executors.newSingleThreadScheduledExecutor(
                r -> new Thread(r, "j-visualizer-cpu-sampler"));

        samplerExecutor.scheduleAtFixedRate(this::collectSample,
                intervalMs, intervalMs, TimeUnit.MILLISECONDS);

        log.info("CPU Sampling started with interval={}ms", intervalMs);
    }

    /**
     * 샘플링 중지
     */
    public void stopSampling() {
        running = false;
        if (samplerExecutor != null) {
            samplerExecutor.shutdown();
        }
    }

    /**
     * 현재 순간의 모든 스레드 스택 트레이스 수집
     */
    private void collectSample() {
        try {
            Map<Thread, StackTraceElement[]> allTraces = Thread.getAllStackTraces();
            String targetPkg = config.getTargetPackage();

            List<StackTrace> relevantTraces = new ArrayList<>();
            for (Map.Entry<Thread, StackTraceElement[]> entry : allTraces.entrySet()) {
                Thread thread = entry.getKey();
                StackTraceElement[] frames = entry.getValue();

                // J-Visualizer 자체 스레드 및 JVM 내부 스레드 제외
                if (thread.getName().startsWith("j-visualizer") || frames.length == 0) {
                    continue;
                }

                // 대상 패키지 포함 여부 확인
                boolean relevant = targetPkg.isEmpty() ||
                        Arrays.stream(frames).anyMatch(f -> f.getClassName().startsWith(targetPkg));

                if (relevant) {
                    relevantTraces.add(new StackTrace(thread.getName(), frames));
                }
            }

            // 빈 snapshot은 추가하지 않음
            if (!relevantTraces.isEmpty()) {
                samples.add(relevantTraces.toArray(new StackTrace[0]));
                totalSamples.incrementAndGet();
            }
        } catch (Exception e) {
            log.warn("Error collecting CPU sample: {}", e.getMessage());
        }
    }

    /**
     * 누적된 샘플을 Flame Graph 데이터로 빌드 후 초기화
     */
    public FlameGraphData buildFlameGraph() {
        if (samples.isEmpty()) return null;

        List<StackTrace[]> currentSamples = new ArrayList<>(samples);
        samples.clear();

        long duration = System.currentTimeMillis() - startTime.getAndSet(System.currentTimeMillis());
        totalSamples.set(0);

        // 스택 트레이스 집계
        Map<String, FrameNode> nodeMap = new LinkedHashMap<>();
        FrameNode root = new FrameNode("root", null);

        int actualSampleCount = 0;
        for (StackTrace[] snapshot : currentSamples) {
            actualSampleCount += snapshot.length;
        }
        root.value = actualSampleCount;
        int sampleCount = actualSampleCount;

        for (StackTrace[] snapshot : currentSamples) {
            for (StackTrace trace : snapshot) {
                StackTraceElement[] frames = trace.frames();

                FrameNode current = root;
                // 전체 스택 포함 (bottom-up → top-down)
                for (int i = frames.length - 1; i >= 0; i--) {
                    StackTraceElement frame = frames[i];
                    String key = frame.getClassName() + "." + frame.getMethodName() + "()";
                    final FrameNode parent = current;
                    FrameNode child = current.children.computeIfAbsent(key,
                            k -> new FrameNode(k, parent));
                    child.value++;
                    if (i == 0) {
                        child.selfTime++;
                    }
                    current = child;
                }
            }
        }

        return new FlameGraphData(
                System.currentTimeMillis(),
                duration,
                sampleCount,
                "CPU_SAMPLING",
                root.toJson()
        );
    }

    // ---- Inner data classes ----

    public record StackTrace(String threadName, StackTraceElement[] frames) {}

    public static class FrameNode {
        public String name;
        public int value;      // 총 샘플 수 (inclusive)
        public int selfTime;   // 자기 자신만의 샘플 수
        public FrameNode parent;
        public Map<String, FrameNode> children = new LinkedHashMap<>();

        public FrameNode(String name, FrameNode parentNode) {
            this.name = name;
            this.parent = parentNode;
        }

        public Map<String, Object> toJson() {
            Map<String, Object> map = new LinkedHashMap<>();
            map.put("name", name);
            map.put("value", value);
            map.put("self_time_ms", selfTime);
            if (!children.isEmpty()) {
                List<Map<String, Object>> childList = new ArrayList<>();
                for (FrameNode child : children.values()) {
                    childList.add(child.toJson());
                }
                map.put("children", childList);
            }
            return map;
        }
    }

    public record FlameGraphData(
            long timestamp,
            long durationMs,
            int totalSamples,
            String profileType,
            Map<String, Object> data
    ) {}
}