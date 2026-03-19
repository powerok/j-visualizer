package com.jvisualizer.backend.websocket;

import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.*;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import java.io.IOException;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * WebSocket 핸들러
 * - Agent 연결 (/ws/agent) : 데이터 수신
 * - Dashboard 연결 (/ws/dashboard) : 데이터 Push
 */
@Component
@Slf4j
@RequiredArgsConstructor
public class ProfilerWebSocketHandler extends TextWebSocketHandler {

    private final ObjectMapper objectMapper;

    // 연결된 세션 관리
    private final Map<String, WebSocketSession> dashboardSessions = new ConcurrentHashMap<>();
    private final Map<String, WebSocketSession> agentSessions = new ConcurrentHashMap<>();

    @Override
    public void afterConnectionEstablished(WebSocketSession session) {
        String uri = session.getUri() != null ? session.getUri().getPath() : "";
        if (uri.contains("agent")) {
            agentSessions.put(session.getId(), session);
            log.info("Agent connected: {} (total agents: {})", session.getId(), agentSessions.size());
        } else {
            dashboardSessions.put(session.getId(), session);
            log.info("Dashboard connected: {} (total dashboards: {})", session.getId(), dashboardSessions.size());
            // 연결 즉시 상태 전송
            sendToSession(session, Map.of(
                    "type", "CONNECTION_ACK",
                    "message", "J-Visualizer Backend 연결 성공",
                    "connectedAgents", agentSessions.size()
            ));
        }
    }

    @Override
    protected void handleTextMessage(WebSocketSession session, TextMessage message) {
        try {
            @SuppressWarnings("unchecked")
            Map<String, Object> payload = objectMapper.readValue(message.getPayload(), Map.class);
            String type = String.valueOf(payload.getOrDefault("type", ""));
            log.debug("WS message received type={} from session={}", type, session.getId());
            // 필요시 양방향 명령 처리 추가 가능 (e.g., TRIGGER_HEAP_DUMP)
        } catch (Exception e) {
            log.warn("Failed to parse WS message: {}", e.getMessage());
        }
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
        dashboardSessions.remove(session.getId());
        agentSessions.remove(session.getId());
        log.info("WS session closed: {} status={}", session.getId(), status);
    }

    @Override
    public void handleTransportError(WebSocketSession session, Throwable exception) {
        log.warn("WS transport error for session {}: {}", session.getId(), exception.getMessage());
        dashboardSessions.remove(session.getId());
        agentSessions.remove(session.getId());
    }

    /**
     * 모든 Dashboard 세션에 메시지 브로드캐스트
     */
    public void broadcast(String type, Object data) {
        if (dashboardSessions.isEmpty()) return;

        try {
            Map<String, Object> envelope = Map.of(
                    "type", type,
                    "data", data,
                    "serverTime", System.currentTimeMillis()
            );
            String json = objectMapper.writeValueAsString(envelope);
            TextMessage message = new TextMessage(json);

            dashboardSessions.values().removeIf(session -> {
                if (!session.isOpen()) return true;
                try {
                    synchronized (session) {
                        session.sendMessage(message);
                    }
                    return false;
                } catch (IOException e) {
                    log.warn("Failed to send to session {}: {}", session.getId(), e.getMessage());
                    return true; // 실패한 세션 제거
                }
            });
        } catch (Exception e) {
            log.error("Broadcast failed", e);
        }
    }

    private void sendToSession(WebSocketSession session, Object data) {
        try {
            String json = objectMapper.writeValueAsString(data);
            synchronized (session) {
                session.sendMessage(new TextMessage(json));
            }
        } catch (Exception e) {
            log.warn("Failed to send to session {}: {}", session.getId(), e.getMessage());
        }
    }

    public int getDashboardCount() { return dashboardSessions.size(); }
    public int getAgentCount() { return agentSessions.size(); }
}