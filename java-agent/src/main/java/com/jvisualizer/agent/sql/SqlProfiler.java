package com.jvisualizer.agent.sql;

import com.jvisualizer.agent.AgentConfig;
import com.jvisualizer.agent.DataSender;
import org.objectweb.asm.*;
import org.objectweb.asm.commons.AdviceAdapter;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.lang.instrument.ClassFileTransformer;
import java.lang.instrument.Instrumentation;
import java.security.ProtectionDomain;
import java.util.*;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.atomic.AtomicLong;

/**
 * SQL Profiler - JDBC Instrumentation 기반
 *
 * ASM을 사용하여 PreparedStatement.execute*() 메서드를 바이트코드 수준에서 인터셉트하여
 * SQL 실행 시간, 호출 빈도, 호출 스택을 수집합니다.
 */
public class SqlProfiler {

    private static final Logger log = LoggerFactory.getLogger(SqlProfiler.class);

    private final AgentConfig config;
    private final Instrumentation instrumentation;
    private final DataSender dataSender;

    // 이벤트 버퍼 (스레드 안전)
    private static final ConcurrentLinkedQueue<SqlEvent> eventBuffer = new ConcurrentLinkedQueue<>();
    private static final AtomicLong totalSqlCount = new AtomicLong(0);
    private static final AtomicLong slowSqlCount = new AtomicLong(0);

    // 정적 참조 (바이트코드에서 접근)
    private static volatile SqlProfiler instance;

    public SqlProfiler(AgentConfig config, Instrumentation instrumentation, DataSender dataSender) {
        this.config = config;
        this.instrumentation = instrumentation;
        this.dataSender = dataSender;
        instance = this;
    }

    public void instrument() {
        try {
            instrumentation.addTransformer(new JdbcTransformer(), true);
            log.info("SQL Profiler instrumentation enabled. SlowSQL threshold: {}ms",
                    config.getSlowSqlThresholdMs());
        } catch (Exception e) {
            log.error("Failed to instrument JDBC classes", e);
        }
    }

    /**
     * SQL 실행 완료 시 바이트코드에서 호출되는 정적 메서드
     */
    public static void onSqlExecuted(String sql, long durationMs, String callerInfo) {
        if (instance == null) return;

        totalSqlCount.incrementAndGet();
        boolean isSlow = durationMs >= instance.config.getSlowSqlThresholdMs();

        if (isSlow) {
            slowSqlCount.incrementAndGet();
            log.warn("SLOW SQL DETECTED ({}ms): {}", durationMs,
                    sql.length() > 100 ? sql.substring(0, 100) + "..." : sql);
        }

        SqlEvent event = new SqlEvent(
                System.currentTimeMillis(),
                sql,
                durationMs,
                isSlow,
                callerInfo
        );
        eventBuffer.offer(event);
        instance.dataSender.sendSqlEvent(event);
    }

    /**
     * 누적 SQL 통계 반환
     */
    public SqlStats getStats() {
        List<SqlEvent> events = new ArrayList<>();
        SqlEvent event;
        while ((event = eventBuffer.poll()) != null) {
            events.add(event);
        }
        return new SqlStats(totalSqlCount.get(), slowSqlCount.get(), events);
    }

    // ---- ASM ClassFileTransformer ----

    private static class JdbcTransformer implements ClassFileTransformer {

        private static final Set<String> TARGET_CLASSES = Set.of(
                "com/mysql/cj/jdbc/PreparedStatement",
                "org/postgresql/jdbc/PgPreparedStatement",
                "oracle/jdbc/driver/OraclePreparedStatement",
                "org/h2/jdbc/JdbcPreparedStatement"
        );

        @Override
        public byte[] transform(ClassLoader loader, String className,
                                Class<?> classBeingRedefined,
                                ProtectionDomain protectionDomain,
                                byte[] classfileBuffer) {

            if (className == null || !TARGET_CLASSES.contains(className)) {
                return null;
            }

            try {
                ClassReader reader = new ClassReader(classfileBuffer);
                ClassWriter writer = new ClassWriter(reader, ClassWriter.COMPUTE_FRAMES);
                ClassVisitor visitor = new JdbcClassVisitor(writer);
                reader.accept(visitor, ClassReader.EXPAND_FRAMES);
                log.info("Instrumented JDBC class: {}", className);
                return writer.toByteArray();
            } catch (Exception e) {
                log.error("Failed to transform class: {}", className, e);
                return null;
            }
        }
    }

    private static class JdbcClassVisitor extends ClassVisitor {
        public JdbcClassVisitor(ClassVisitor cv) {
            super(Opcodes.ASM9, cv);
        }

        @Override
        public MethodVisitor visitMethod(int access, String name, String descriptor,
                                         String signature, String[] exceptions) {
            MethodVisitor mv = super.visitMethod(access, name, descriptor, signature, exceptions);
            if (name.startsWith("execute") &&
                    (name.equals("execute") || name.equals("executeQuery") ||
                     name.equals("executeUpdate") || name.equals("executeBatch"))) {
                return new SqlMethodAdvice(mv, access, name, descriptor);
            }
            return mv;
        }
    }

    private static class SqlMethodAdvice extends AdviceAdapter {
        private int startTimeVar;

        public SqlMethodAdvice(MethodVisitor mv, int access, String name, String descriptor) {
            super(Opcodes.ASM9, mv, access, name, descriptor);
        }

        @Override
        protected void onMethodEnter() {
            startTimeVar = newLocal(Type.LONG_TYPE);
            // long startTime = System.currentTimeMillis();
            mv.visitMethodInsn(INVOKESTATIC, "java/lang/System",
                    "currentTimeMillis", "()J", false);
            mv.visitVarInsn(LSTORE, startTimeVar);
        }

        @Override
        protected void onMethodExit(int opcode) {
            if (opcode == ATHROW) return;

            // long duration = System.currentTimeMillis() - startTime;
            mv.visitMethodInsn(INVOKESTATIC, "java/lang/System",
                    "currentTimeMillis", "()J", false);
            mv.visitVarInsn(LLOAD, startTimeVar);
            mv.visitInsn(LSUB);

            // SqlProfiler.onSqlExecuted(this.toString(), duration, "")
            mv.visitVarInsn(LSTORE, startTimeVar + 2);
            mv.visitVarInsn(ALOAD, 0);
            mv.visitMethodInsn(INVOKEVIRTUAL, "java/lang/Object",
                    "toString", "()Ljava/lang/String;", false);
            mv.visitVarInsn(LLOAD, startTimeVar + 2);
            mv.visitLdcInsn("jdbc");
            mv.visitMethodInsn(INVOKESTATIC,
                    "com/jvisualizer/agent/sql/SqlProfiler",
                    "onSqlExecuted",
                    "(Ljava/lang/String;JLjava/lang/String;)V",
                    false);
        }
    }

    // ---- Inner data classes ----

    public record SqlEvent(
            long timestamp,
            String sql,
            long executionMs,
            boolean isSlowQuery,
            String callerMethod
    ) {
        public Map<String, Object> toMap() {
            Map<String, Object> map = new LinkedHashMap<>();
            map.put("timestamp", timestamp);
            map.put("sql", sql);
            map.put("execution_ms", executionMs);
            map.put("is_slow_query", isSlowQuery);
            map.put("caller_method", callerMethod);
            return map;
        }
    }

    public record SqlStats(
            long totalCount,
            long slowCount,
            List<SqlEvent> recentEvents
    ) {}
}
