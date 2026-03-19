package com.jvisualizer.backend.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import lombok.Builder;

import java.time.Instant;

@Entity
@Table(name = "cpu_profiles")
@Data @NoArgsConstructor @AllArgsConstructor @Builder
public class CpuProfile {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private String id;

    private Instant timestamp;
    private long durationMs;
    private int totalSamples;
    private String profileType;

    @Column(columnDefinition = "TEXT")
    private String flameGraphJson;  // JSON 직렬화된 flame graph 트리

    private String appName;
}
