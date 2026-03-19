package com.jvisualizer.backend.repository;

import com.jvisualizer.backend.model.JvmMetrics;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;

@Repository
public interface JvmMetricsRepository extends JpaRepository<JvmMetrics, String> {

    List<JvmMetrics> findTop60ByOrderByTimestampDesc();

    List<JvmMetrics> findByTimestampAfterOrderByTimestampAsc(Instant after);

    @Query("SELECT m FROM JvmMetrics m WHERE m.timestamp >= :from ORDER BY m.timestamp ASC")
    List<JvmMetrics> findMetricsSince(Instant from);

    void deleteByTimestampBefore(Instant before);
}
