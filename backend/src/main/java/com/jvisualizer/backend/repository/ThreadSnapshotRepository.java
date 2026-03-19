package com.jvisualizer.backend.repository;

import com.jvisualizer.backend.model.ThreadSnapshot;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface ThreadSnapshotRepository extends JpaRepository<ThreadSnapshot, String> {
    Optional<ThreadSnapshot> findTopByOrderByTimestampDesc();
}
