package com.jvisualizer.backend.config;

import com.jvisualizer.backend.websocket.ProfilerWebSocketHandler;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.socket.config.annotation.EnableWebSocket;
import org.springframework.web.socket.config.annotation.WebSocketConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry;

@Configuration
@EnableWebSocket
public class WebSocketConfig implements WebSocketConfigurer {

    private final ProfilerWebSocketHandler webSocketHandler;

    public WebSocketConfig(ProfilerWebSocketHandler webSocketHandler) {
        this.webSocketHandler = webSocketHandler;
    }

    @Override
    public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
        // Flutter Dashboard 연결 엔드포인트
        registry.addHandler(webSocketHandler, "/ws/dashboard")
                .setAllowedOrigins("*");

        // Java Agent 연결 엔드포인트 (동일 핸들러 재사용)
        registry.addHandler(webSocketHandler, "/ws/agent")
                .setAllowedOrigins("*");
    }
}
