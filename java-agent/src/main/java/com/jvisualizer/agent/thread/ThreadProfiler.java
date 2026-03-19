package com.jvisualizer.agent.thread;

import com.jvisualizer.agent.DataSender;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.lang.management.ManagementFactory;
import java.lang.management.ThreadInfo;
import java.lang.management.ThreadMXBean;
import java.util.*;

/**
 * Thread Profiler
 *
 * 스레드 상태(Running/Waiting/Blocked), Deadlock을 감지하고
 * Thread Dump 데이터를 수집합니다.
 */
public class ThreadProfiler {

    private static final Logger log = LoggerFactory.getLogger(ThreadProfiler.class);

    private final DataSender dataSender;
    private final ThreadMXBean threadBean;

    public ThreadProfiler(DataSender dataSender) {
        this.dataSender = dataSender;
        this.threadBean = ManagementFactory.getThreadMXBean();
        threadBean.setThreadContentionMonitoringEnabled(true);
        threadBean.setThreadCpuTimeEnabled(true);
    }

    /**
     * 스레드 통계 요약 반환 (메트릭 데이터용)
     */
    public ThreadStats getThreadStats() {
        ThreadInfo[] allThreads = threadBean.getThreadInfo(threadBean.getAllThreadIds(), 0);

        int running = 0, waiting = 0, blocked = 0, total = 0;
        for (ThreadInfo ti : allThreads) {
            if (ti == null) continue;
            total++;
            switch (ti.getThreadState()) {
                case RUNNABLE -> running++;
                case WAITING, TIMED_WAITING -> waiting++;
                case BLOCKED -> blocked++;
            }
        }

        // Deadlock 감지
        long[] deadlockedIds = threadBean.findDeadlockedThreads();
        int deadlockCount = deadlockedIds != null ? deadlockedIds.length : 0;

        return new ThreadStats(total, running, waiting, blocked, deadlockCount);
    }

    /**
     * 전체 Thread Dump 수집
     */
    public ThreadDumpData getThreadDump() {
        ThreadInfo[] allThreads = threadBean.dumpAllThreads(true, true);
        List<Map<String, Object>> threadList = new ArrayList<>();

        for (ThreadInfo ti : allThreads) {
            Map<String, Object> threadMap = new LinkedHashMap<>();
            threadMap.put("id", ti.getThreadId());
            threadMap.put("name", ti.getThreadName());
            threadMap.put("state", ti.getThreadState().name());
            threadMap.put("cpu_time_ms", threadBean.getThreadCpuTime(ti.getThreadId()) / 1_000_000);
            threadMap.put("blocked_time_ms", ti.getBlockedTime());
            threadMap.put("blocked_count", ti.getBlockedCount());
            threadMap.put("waited_count", ti.getWaitedCount());

            if (ti.getLockName() != null) {
                threadMap.put("lock_name", ti.getLockName());
            }
            if (ti.getLockOwnerName() != null) {
                threadMap.put("lock_owner_id", ti.getLockOwnerId());
                threadMap.put("lock_owner_name", ti.getLockOwnerName());
            }

            // Stack Trace 변환
            StackTraceElement[] frames = ti.getStackTrace();
            List<String> stackTrace = new ArrayList<>();
            for (StackTraceElement frame : frames) {
                stackTrace.add(frame.toString());
            }
            threadMap.put("stack_trace", stackTrace);

            threadList.add(threadMap);
        }

        // Deadlock 정보
        long[] deadlockedIds = threadBean.findDeadlockedThreads();
        List<Long> deadlocks = new ArrayList<>();
        if (deadlockedIds != null) {
            for (long id : deadlockedIds) {
                deadlocks.add(id);
                log.warn("DEADLOCK DETECTED! Thread ID: {}", id);
            }
        }

        return new ThreadDumpData(System.currentTimeMillis(), threadList, deadlocks);
    }

    // ---- Inner data classes ----

    public record ThreadStats(
            int totalCount,
            int runningCount,
            int waitingCount,
            int blockedCount,
            int deadlockCount
    ) {
        public Map<String, Object> toMap() {
            Map<String, Object> map = new LinkedHashMap<>();
            map.put("thread_count", totalCount);
            map.put("running_count", runningCount);
            map.put("waiting_count", waitingCount);
            map.put("blocked_count", blockedCount);
            map.put("deadlock_count", deadlockCount);
            return map;
        }
    }

    public record ThreadDumpData(
            long timestamp,
            List<Map<String, Object>> threads,
            List<Long> deadlockedThreadIds
    ) {}
}
