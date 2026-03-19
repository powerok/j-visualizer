package com.jvisualizer.backend.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;
import lombok.Builder;

import java.time.Instant;

@Entity
@Table(name = "sql_events")
@Data @NoArgsConstructor @AllArgsConstructor @Builder
public class SqlEvent {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private String id;

    private Instant timestamp;

    @Column(columnDefinition = "TEXT")
    private String sql;

    private long executionMs;
    private boolean slowQuery;
    private String callerMethod;
    private String appName;
}
