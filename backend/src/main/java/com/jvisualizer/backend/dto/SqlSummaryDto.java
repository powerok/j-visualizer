package com.jvisualizer.backend.dto;

import com.jvisualizer.backend.model.SqlEvent;
import java.time.Instant;
import java.util.List;

public record SqlSummaryDto(
        long totalCount,
        long slowCount,
        List<SqlEvent> slowestQueries
) {}
