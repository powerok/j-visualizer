package com.jvisualizer.backend.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import lombok.Builder;

import java.time.Instant;

@Entity
@Table(name = "thread_snapshots")
@Data @NoArgsConstructor @AllArgsConstructor @Builder
public class ThreadSnapshot {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private String id;

    private Instant timestamp;
    private int totalThreads;
    private int runningCount;
    private int waitingCount;
    private int blockedCount;
    private int deadlockCount;

    @Column(columnDefinition = "TEXT")
    private String threadDumpJson; // 전체 Thread Dump JSON

    private String appName;
}
