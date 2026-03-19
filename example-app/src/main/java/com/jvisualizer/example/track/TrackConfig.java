package com.jvisualizer.example.track;

import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.filter.OncePerRequestFilter;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.LinkedHashMap;
import java.util.Map;

@Configuration
@Slf4j
public class TrackConfig {

    @Value("${jvisualizer.backend-url:http://localhost:8080}")
    private String backendUrl;

    @Bean
    public FilterRegistrationBean<TrackFilter> trackFilter() {
        FilterRegistrationBean<TrackFilter> bean = new FilterRegistrationBean<>();
        bean.setFilter(new TrackFilter(backendUrl));
        bean.addUrlPatterns("/test/*");
        bean.setOrder(1);
        return bean;
    }

    @Slf4j
    public static class TrackFilter extends OncePerRequestFilter {

        private final String backendUrl;
        private static final HttpClient HTTP = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(3)).build();
        private static final ObjectMapper MAPPER = new ObjectMapper();

        public TrackFilter(String backendUrl) {
            this.backendUrl = backendUrl;
        }

        @Override
        protected void doFilterInternal(HttpServletRequest request,
                                        HttpServletResponse response,
                                        FilterChain chain)
                throws ServletException, IOException {

            InvocationContext ctx = InvocationContext.start();
            String httpEntry = "[HTTP] " + request.getMethod() + " " + request.getRequestURI();
            ctx.push(httpEntry);
            long start = System.currentTimeMillis();

            try {
                chain.doFilter(request, response);
            } finally {
                ctx.pop();
                long elapsed = System.currentTimeMillis() - start;

                try {
                    if (ctx.hasData()) {
                        InvocationNode root = ctx.getRoot();
                        String treeText = root.toText(0, elapsed);
                        // Jackson으로 안전하게 JSON 빌드
                        Map<String, Object> treeMap = nodeToMap(root);
                        String treeJson = MAPPER.writeValueAsString(treeMap);

                        Map<String, Object> payload = new LinkedHashMap<>();
                        payload.put("endpoint", request.getMethod() + " " + request.getRequestURI());
                        payload.put("elapsed_ms", elapsed);
                        payload.put("status", response.getStatus());
                        payload.put("timestamp", System.currentTimeMillis());
                        payload.put("app_name", "j-visualizer-example");
                        payload.put("tree_text", treeText);
                        payload.put("tree", treeMap); // Map으로 전달 (Jackson이 직렬화)

                        String json = MAPPER.writeValueAsString(payload);
                        sendAsync(json);
                        log.debug("Invocation sent: {} {}ms depth={}", 
                            request.getRequestURI(), elapsed, countNodes(root));
                    }
                } catch (Exception e) {
                    log.warn("TrackFilter send error: {}", e.getMessage());
                } finally {
                    InvocationContext.clear();
                }
            }
        }

        private Map<String, Object> nodeToMap(InvocationNode node) {
            Map<String, Object> map = new LinkedHashMap<>();
            String fullName = node.getName();
            String shortName = fullName;
            String[] parts = fullName.split("\\.");
            if (parts.length > 2) {
                shortName = parts[parts.length - 2] + "." + parts[parts.length - 1];
            }
            map.put("name", shortName);
            map.put("full_name", fullName);
            map.put("duration_ms", node.getDurationMs());
            if (!node.getChildren().isEmpty()) {
                map.put("children", node.getChildren().stream()
                        .map(this::nodeToMap).toList());
            }
            return map;
        }

        private int countNodes(InvocationNode node) {
            return 1 + node.getChildren().stream().mapToInt(this::countNodes).sum();
        }

        private void sendAsync(String json) {
            try {
                HttpRequest req = HttpRequest.newBuilder()
                        .uri(URI.create(backendUrl + "/api/invocations"))
                        .header("Content-Type", "application/json")
                        .POST(HttpRequest.BodyPublishers.ofString(json))
                        .timeout(Duration.ofSeconds(5))
                        .build();
                HTTP.sendAsync(req, HttpResponse.BodyHandlers.discarding())
                        .exceptionally(e -> { log.debug("send failed: {}", e.getMessage()); return null; });
            } catch (Exception e) {
                log.debug("sendAsync error: {}", e.getMessage());
            }
        }
    }
}