package com.jvisualizer.backend.dto;

import java.time.Instant;
import java.util.List;

public record BottleneckReportDto(
        Instant analyzedAt,
        List<String> issues,
        int analyzedSampleCount
) {}
