package com.jvisualizer.backend.repository;

import com.jvisualizer.backend.model.CpuProfile;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface CpuProfileRepository extends JpaRepository<CpuProfile, String> {
    Optional<CpuProfile> findTopByOrderByTimestampDesc();
    List<CpuProfile> findTop10ByOrderByTimestampDesc();
}
