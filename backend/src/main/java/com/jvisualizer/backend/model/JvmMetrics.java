package com.jvisualizer.backend.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import lombok.Builder;

import java.time.Instant;

@Entity
@Table(name = "jvm_metrics")
@Data @NoArgsConstructor @AllArgsConstructor @Builder
public class JvmMetrics {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private String id;

    private Instant timestamp;

    // Heap
    private long heapUsed;
    private long heapMax;
    private long heapCommitted;
    private long nonHeapUsed;
    private double heapUsedPercent;

    // Thread
    private int threadCount;
    private int runningCount;
    private int waitingCount;
    private int blockedCount;
    private int deadlockCount;

    // GC
    private long gcCollectionCount;
    private long gcCollectionTimeMs;
    private String lastGcCause;

    // CPU (JVM 프로세스 CPU 사용률)
    private double cpuUsagePercent;

    // Agent 정보
    private String appName;
    private long agentPid;
}
