package com.jvisualizer.backend.model;

import jakarta.persistence.*;
import lombok.*;
import java.time.Instant;

@Entity
@Table(name = "invocation_records")
@Data @NoArgsConstructor @AllArgsConstructor @Builder
public class InvocationRecord {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private String id;

    private Instant timestamp;
    private String endpoint;
    private long elapsedMs;
    private int httpStatus;
    private String appName;

    @Column(columnDefinition = "TEXT")
    private String treeText;   // 텍스트 트리 (사람이 읽기 쉬운 형태)

    @Column(columnDefinition = "TEXT")
    private String treeJson;   // JSON 트리 (Flutter 렌더링용)
}