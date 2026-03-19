package com.jvisualizer.example.sql;

import org.hibernate.resource.jdbc.spi.StatementInspector;

import java.util.ArrayList;
import java.util.List;

/**
 * Hibernate StatementInspector - 실행되는 SQL을 ThreadLocal로 캡처
 */
public class SqlCapture implements StatementInspector {

    public record CapturedSql(String sql, long capturedAt) {}

    private static final ThreadLocal<List<CapturedSql>> HOLDER = new ThreadLocal<>();

    public static void start() {
        HOLDER.set(new ArrayList<>());
    }

    public static List<CapturedSql> stop() {
        List<CapturedSql> result = HOLDER.get();
        HOLDER.remove();
        return result != null ? result : List.of();
    }

    public static boolean isCapturing() {
        return HOLDER.get() != null;
    }

    @Override
    public String inspect(String sql) {
        List<CapturedSql> list = HOLDER.get();
        if (list != null) {
            list.add(new CapturedSql(sql, System.currentTimeMillis()));
        }
        return sql; // SQL 변경 없이 그대로 통과
    }
}