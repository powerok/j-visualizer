package com.jvisualizer.backend.repository;

import com.jvisualizer.backend.model.SqlEvent;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface SqlEventRepository extends JpaRepository<SqlEvent, String> {
    List<SqlEvent> findTop100ByOrderByTimestampDesc();
    List<SqlEvent> findBySlowQueryTrueOrderByExecutionMsDesc();

    @Query("SELECT s FROM SqlEvent s ORDER BY s.executionMs DESC LIMIT 20")
    List<SqlEvent> findSlowest20();

    long countBySlowQueryTrue();
}
