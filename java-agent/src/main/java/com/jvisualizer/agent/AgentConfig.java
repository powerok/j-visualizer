package com.jvisualizer.agent;

/**
 * Java Agent 설정 파싱 및 보관
 *
 * 파라미터 형식:
 *   server=http://localhost:8080,mode=sampling,interval=10,package=com.example,flushInterval=5000
 */
public class AgentConfig {

    public enum ProfilingMode {
        SAMPLING,       // 주기적 스택 추출 (운영 환경 권장)
        INSTRUMENTING   // 바이트코드 삽입 (개발/QA 환경 권장)
    }

    private String serverUrl;
    private ProfilingMode mode;
    private int samplingIntervalMs;
    private String targetPackage;
    private int flushIntervalMs;
    private boolean sqlProfilingEnabled;
    private int slowSqlThresholdMs;

    // 기본값 설정
    private AgentConfig() {
        this.serverUrl = "http://localhost:8080";
        this.mode = ProfilingMode.SAMPLING;
        this.samplingIntervalMs = 10;
        this.targetPackage = "";  // 기본값: 빈 문자열 = 모든 패키지 수집
        this.flushIntervalMs = 5000;
        this.sqlProfilingEnabled = true;
        this.slowSqlThresholdMs = 1000;
    }

    public static AgentConfig parse(String agentArgs) {
        AgentConfig config = new AgentConfig();
        if (agentArgs == null || agentArgs.isBlank()) {
            return config;
        }

        String[] parts = agentArgs.split(",");
        for (String part : parts) {
            String[] kv = part.split("=", 2);
            if (kv.length != 2) continue;
            String key = kv[0].trim();
            String value = kv[1].trim();

            switch (key) {
                case "server" -> config.serverUrl = value;
                case "mode" -> config.mode = ProfilingMode.valueOf(value.toUpperCase());
                case "interval" -> config.samplingIntervalMs = Integer.parseInt(value);
                case "package" -> config.targetPackage = value;
                case "flushInterval" -> config.flushIntervalMs = Integer.parseInt(value);
                case "sqlProfiling" -> config.sqlProfilingEnabled = Boolean.parseBoolean(value);
                case "slowSqlThreshold" -> config.slowSqlThresholdMs = Integer.parseInt(value);
            }
        }
        return config;
    }

    // Getters
    public String getServerUrl() { return serverUrl; }
    public ProfilingMode getMode() { return mode; }
    public int getSamplingIntervalMs() { return samplingIntervalMs; }
    public String getTargetPackage() { return targetPackage; }
    public int getFlushIntervalMs() { return flushIntervalMs; }
    public boolean isSqlProfilingEnabled() { return sqlProfilingEnabled; }
    public int getSlowSqlThresholdMs() { return slowSqlThresholdMs; }

    public String getWebSocketUrl() {
        return serverUrl.replace("http://", "ws://")
                        .replace("https://", "wss://") + "/ws/agent";
    }

    @Override
    public String toString() {
        return "AgentConfig{" +
                "serverUrl='" + serverUrl + '\'' +
                ", mode=" + mode +
                ", samplingIntervalMs=" + samplingIntervalMs +
                ", targetPackage='" + targetPackage + '\'' +
                ", flushIntervalMs=" + flushIntervalMs +
                ", sqlProfilingEnabled=" + sqlProfilingEnabled +
                '}';
    }
}