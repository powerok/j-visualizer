package com.jvisualizer.example.repository;

import com.jvisualizer.example.model.Product;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.util.List;

@Repository
public interface ProductRepository extends JpaRepository<Product, Long> {

    List<Product> findByCategory(String category);

    // 의도적으로 N+1이 발생할 수 있는 쿼리 (테스트용)
    List<Product> findByPriceLessThan(BigDecimal price);

    // Slow Query 시뮬레이션을 위한 네이티브 쿼리
    @Query(value = "SELECT * FROM products p WHERE p.name LIKE CONCAT('%', :keyword, '%')", nativeQuery = true)
    List<Product> searchByName(String keyword);

    @Query("SELECT p FROM Product p WHERE p.stock > 0 ORDER BY p.price DESC")
    List<Product> findAvailableProductsSortedByPrice();
}
