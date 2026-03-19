package com.jvisualizer.example.service;

import com.jvisualizer.example.model.Product;
import com.jvisualizer.example.repository.ProductRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.*;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.locks.ReentrantLock;
import java.util.stream.Collectors;
import java.util.stream.IntStream;

/**
 * 프로파일러 테스트를 위한 다양한 병목 시나리오를 제공하는 서비스
 *
 * 각 메서드는 의도적으로 성능 문제를 유발하여
 * J-Visualizer Agent가 수집한 데이터를 Dashboard에서 시각화할 수 있게 합니다.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class OrderService {

    private final ProductRepository productRepository;

    // Deadlock 테스트용 Lock
    private final ReentrantLock lockA = new ReentrantLock();
    private final ReentrantLock lockB = new ReentrantLock();

    // 메모리 누수 시뮬레이션용 버퍼
    private final List<byte[]> memoryLeakBuffer = new ArrayList<>();

    // ────────────────────────────────────────────────────────────
    // 시나리오 1: CPU 집약적 작업 (Flame Graph에 뚜렷하게 표시됨)
    // ────────────────────────────────────────────────────────────

    public Map<String, Object> runCpuIntensiveTask(int iterations) {
        long start = System.currentTimeMillis();
        log.info("Starting CPU intensive task: {} iterations", iterations);

        // 중첩 호출 구조를 만들어 Flame Graph에서 시각화
        long result = computeLayer1(iterations);

        long elapsed = System.currentTimeMillis() - start;
        return Map.of(
                "result", result,
                "elapsed_ms", elapsed,
                "iterations", iterations
        );
    }

    private long computeLayer1(int n) {
        long sum = 0;
        for (int i = 0; i < n; i++) {
            sum += computeLayer2(i);
        }
        return sum;
    }

    private long computeLayer2(int n) {
        return computeLayer3(n) + sortHeavy(n);
    }

    private long computeLayer3(int n) {
        // 소수 판별 (CPU 부하)
        long count = 0;
        for (int i = 2; i <= Math.min(n + 100, 10000); i++) {
            if (isPrime(i)) count++;
        }
        return count;
    }

    private boolean isPrime(int n) {
        if (n < 2) return false;
        for (int i = 2; i <= Math.sqrt(n); i++) {
            if (n % i == 0) return false;
        }
        return true;
    }

    private long sortHeavy(int n) {
        // 정렬 작업 (CPU 부하)
        List<Integer> list = IntStream.range(0, Math.min(n + 50, 5000))
                .boxed()
                .collect(Collectors.toCollection(ArrayList::new));
        Collections.shuffle(list);
        Collections.sort(list);
        return list.stream().mapToLong(Integer::longValue).sum();
    }

    // ────────────────────────────────────────────────────────────
    // 시나리오 2: 메모리 누수 시뮬레이션 (Heap 사용량 증가)
    // ────────────────────────────────────────────────────────────

    public Map<String, Object> simulateMemoryLeak(int mbToAllocate) {
        log.warn("Simulating memory leak: allocating {}MB", mbToAllocate);
        int before = memoryLeakBuffer.size();

        // 1MB 청크씩 할당 (GC가 수집하지 못하도록 강한 참조 유지)
        for (int i = 0; i < mbToAllocate; i++) {
            memoryLeakBuffer.add(new byte[1024 * 1024]); // 1MB
        }

        Runtime rt = Runtime.getRuntime();
        long usedMb = (rt.totalMemory() - rt.freeMemory()) / (1024 * 1024);
        long maxMb = rt.maxMemory() / (1024 * 1024);

        return Map.of(
                "allocated_mb", mbToAllocate,
                "buffer_chunks", memoryLeakBuffer.size() - before,
                "jvm_used_mb", usedMb,
                "jvm_max_mb", maxMb,
                "usage_percent", (double) usedMb / maxMb * 100
        );
    }

    public Map<String, Object> releaseMemory() {
        int released = memoryLeakBuffer.size();
        memoryLeakBuffer.clear();
        System.gc();
        return Map.of("released_chunks", released, "status", "released");
    }

    // ────────────────────────────────────────────────────────────
    // 시나리오 3: Slow SQL 시뮬레이션 (SQL Profiler 테스트)
    // ────────────────────────────────────────────────────────────

    @Transactional(readOnly = true)
    public Map<String, Object> runSlowSqlTest() {
        long start = System.currentTimeMillis();

        // 의도적으로 비효율적인 쿼리들
        List<Product> all = productRepository.findAll();

        // N+1 문제 시뮬레이션: 각 카테고리별로 개별 쿼리
        List<Map<String, Object>> results = new ArrayList<>();
        Set<String> categories = all.stream()
                .map(Product::getCategory)
                .collect(Collectors.toSet());

        for (String category : categories) {
            List<Product> byCategory = productRepository.findByCategory(category);
            // 인위적 지연
            try { Thread.sleep(50); } catch (InterruptedException e) { Thread.currentThread().interrupt(); }
            results.add(Map.of(
                    "category", category,
                    "count", byCategory.size()
            ));
        }

        // LIKE 검색 (Full Scan 유발)
        List<Product> searched = productRepository.searchByName("Pro");

        long elapsed = System.currentTimeMillis() - start;
        return Map.of(
                "total_products", all.size(),
                "categories_queried", categories.size(),
                "search_results", searched.size(),
                "elapsed_ms", elapsed,
                "warning", "This test intentionally causes N+1 queries!"
        );
    }

    // ────────────────────────────────────────────────────────────
    // 시나리오 4: Thread Contention (BLOCKED 스레드 생성)
    // ────────────────────────────────────────────────────────────

    public Map<String, Object> simulateThreadContention(int threadCount) throws InterruptedException {
        log.info("Simulating thread contention with {} threads", threadCount);
        CountDownLatch startLatch = new CountDownLatch(1);
        CountDownLatch doneLatch = new CountDownLatch(threadCount);
        List<Long> times = Collections.synchronizedList(new ArrayList<>());

        ExecutorService executor = Executors.newFixedThreadPool(threadCount);
        for (int i = 0; i < threadCount; i++) {
            final int threadId = i;
            executor.submit(() -> {
                try {
                    startLatch.await(); // 동시 시작
                    long start = System.currentTimeMillis();
                    // 모든 스레드가 동일한 락에 경합
                    synchronized (this) {
                        Thread.sleep(100); // 락 보유 중 지연
                        times.add(System.currentTimeMillis() - start);
                    }
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                } finally {
                    doneLatch.countDown();
                }
            });
        }

        startLatch.countDown(); // 일제히 시작
        doneLatch.await();
        executor.shutdown();

        long avgWait = times.stream().mapToLong(Long::longValue).sum() / times.size();
        long maxWait = times.stream().mapToLong(Long::longValue).max().orElse(0);

        return Map.of(
                "thread_count", threadCount,
                "avg_wait_ms", avgWait,
                "max_wait_ms", maxWait,
                "info", "Check Thread Profiler tab for BLOCKED threads"
        );
    }

    // ────────────────────────────────────────────────────────────
    // 시나리오 5: Deadlock 시뮬레이션
    // ────────────────────────────────────────────────────────────

    public Map<String, Object> simulateDeadlock() {
        log.warn("Simulating DEADLOCK - check Thread Profiler!");

        Thread t1 = new Thread(() -> {
            lockA.lock();
            try {
                Thread.sleep(100);
                lockB.lock(); // t2가 lockB를 보유 중 → DEADLOCK
                try {
                    log.info("Thread-1: acquired both locks");
                } finally {
                    lockB.unlock();
                }
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            } finally {
                lockA.unlock();
            }
        }, "deadlock-thread-1");

        Thread t2 = new Thread(() -> {
            lockB.lock();
            try {
                Thread.sleep(100);
                lockA.lock(); // t1이 lockA를 보유 중 → DEADLOCK
                try {
                    log.info("Thread-2: acquired both locks");
                } finally {
                    lockA.unlock();
                }
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            } finally {
                lockB.unlock();
            }
        }, "deadlock-thread-2");

        t1.setDaemon(true);
        t2.setDaemon(true);
        t1.start();
        t2.start();

        return Map.of(
                "status", "deadlock_initiated",
                "threads", List.of("deadlock-thread-1", "deadlock-thread-2"),
                "warning", "Deadlock threads are running! Check Thread Profiler tab.",
                "note", "Threads are daemon so they won't prevent JVM shutdown"
        );
    }

    // ────────────────────────────────────────────────────────────
    // 시나리오 6: 복합 부하 테스트
    // ────────────────────────────────────────────────────────────

    public Map<String, Object> runFullLoad() throws InterruptedException {
        Map<String, Object> results = new LinkedHashMap<>();
        results.put("cpu", runCpuIntensiveTask(500));
        results.put("memory", simulateMemoryLeak(10));
        results.put("sql", runSlowSqlTest());
        results.put("thread", simulateThreadContention(5));
        results.put("status", "full_load_completed");
        return results;
    }

    // ────────────────────────────────────────────────────────────
    // 데이터 초기화
    // ────────────────────────────────────────────────────────────

    @Transactional
    public void initSampleData() {
        if (productRepository.count() > 0) return;

        String[] categories = {"Electronics", "Clothing", "Books", "Food", "Sports"};
        String[] adjectives = {"Premium", "Standard", "Pro", "Lite", "Ultra", "Basic"};
        Random random = new Random(42);

        List<Product> products = new ArrayList<>();
        for (int i = 1; i <= 200; i++) {
            products.add(Product.builder()
                    .name(adjectives[i % adjectives.length] + " Product " + i)
                    .category(categories[i % categories.length])
                    .price(BigDecimal.valueOf(10 + random.nextInt(990)))
                    .stock(random.nextInt(100))
                    .build());
        }
        productRepository.saveAll(products);
        log.info("Initialized {} sample products", products.size());
    }
}
