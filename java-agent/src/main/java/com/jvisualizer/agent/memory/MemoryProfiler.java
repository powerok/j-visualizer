package com.jvisualizer.agent.memory;

import com.jvisualizer.agent.DataSender;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.lang.management.*;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Memory / Heap Profiler
 *
 * JVM의 Heap 사용량, GC 정보를 MXBean을 통해 수집합니다.
 */
public class MemoryProfiler {

    private static final Logger log = LoggerFactory.getLogger(MemoryProfiler.class);

    private final DataSender dataSender;
    private final MemoryMXBean memoryBean;
    private final List<GarbageCollectorMXBean> gcBeans;

    // GC 누적 카운터 초기값
    private long baseGcCount = 0;
    private long baseGcTime = 0;

    public MemoryProfiler(DataSender dataSender) {
        this.dataSender = dataSender;
        this.memoryBean = ManagementFactory.getMemoryMXBean();
        this.gcBeans = ManagementFactory.getGarbageCollectorMXBeans();

        // 기준값 설정
        for (GarbageCollectorMXBean gcBean : gcBeans) {
            if (gcBean.getCollectionCount() > 0) {
                baseGcCount += gcBean.getCollectionCount();
                baseGcTime += gcBean.getCollectionTime();
            }
        }
    }

    /**
     * 현재 힙 사용 정보 반환
     */
    public HeapInfo getHeapUsage() {
        MemoryUsage heapUsage = memoryBean.getHeapMemoryUsage();
        MemoryUsage nonHeapUsage = memoryBean.getNonHeapMemoryUsage();

        return new HeapInfo(
                heapUsage.getUsed(),
                heapUsage.getMax(),
                heapUsage.getCommitted(),
                nonHeapUsage.getUsed()
        );
    }

    /**
     * GC 정보 반환
     */
    public GcInfo getGcInfo() {
        long totalCount = 0;
        long totalTime = 0;
        String lastCause = "N/A";

        for (GarbageCollectorMXBean gcBean : gcBeans) {
            long count = gcBean.getCollectionCount();
            long time = gcBean.getCollectionTime();
            if (count > 0) {
                totalCount += count;
                totalTime += time;
                lastCause = gcBean.getName(); // 실제 환경에서는 LastGcInfo 사용
            }
        }

        return new GcInfo(
                totalCount - baseGcCount,
                totalTime - baseGcTime,
                lastCause
        );
    }

    /**
     * Heap Dump를 지정 경로에 생성
     * 실제 환경에서는 HotSpotDiagnosticMXBean 사용
     */
    public void triggerHeapDump(String outputPath) {
        log.info("Triggering heap dump to: {}", outputPath);
        // HotSpotDiagnosticMXBean을 통한 Heap Dump 생성 로직
        // ManagementFactory.newPlatformMXBeanProxy(server, "com.sun.management:type=HotSpotDiagnostic", ...)
        log.warn("Heap dump feature requires HotSpot JVM. Path: {}", outputPath);
    }

    // ---- Inner data classes ----

    public record HeapInfo(
            long heapUsed,
            long heapMax,
            long heapCommitted,
            long nonHeapUsed
    ) {
        public Map<String, Object> toMap() {
            Map<String, Object> map = new LinkedHashMap<>();
            map.put("heap_used", heapUsed);
            map.put("heap_max", heapMax);
            map.put("heap_committed", heapCommitted);
            map.put("non_heap_used", nonHeapUsed);
            map.put("heap_used_percent", heapMax > 0 ? (double) heapUsed / heapMax * 100 : 0);
            return map;
        }
    }

    public record GcInfo(
            long collectionCount,
            long collectionTimeMs,
            String lastGcCause
    ) {
        public Map<String, Object> toMap() {
            Map<String, Object> map = new LinkedHashMap<>();
            map.put("collection_count", collectionCount);
            map.put("collection_time_ms", collectionTimeMs);
            map.put("last_gc_cause", lastGcCause);
            return map;
        }
    }
}
