package com.jvisualizer.example;

import com.jvisualizer.example.service.OrderService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
@Slf4j
public class DataInitializer implements ApplicationRunner {

    private final OrderService orderService;

    @Override
    public void run(ApplicationArguments args) {
        log.info("Initializing sample data...");
        orderService.initSampleData();
        log.info("==============================================");
        log.info("  J-Visualizer Example App is ready!");
        log.info("  Test endpoints: http://localhost:8090/test");
        log.info("  H2 Console:     http://localhost:8090/h2-console");
        log.info("==============================================");
    }
}
