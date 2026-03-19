package com.jvisualizer.backend.repository;

import com.jvisualizer.backend.model.InvocationRecord;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
public interface InvocationRecordRepository extends JpaRepository<InvocationRecord, String> {
    List<InvocationRecord> findTop100ByOrderByTimestampDesc();
    List<InvocationRecord> findByEndpointContainingOrderByTimestampDesc(String endpoint);
}