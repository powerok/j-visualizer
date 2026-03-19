package com.jvisualizer.example.track;

import java.util.ArrayDeque;
import java.util.Deque;

/**
 * ThreadLocal 기반 호출 컨텍스트
 * 각 스레드(HTTP 요청)별로 독립적인 호출 트리를 유지합니다.
 */
public class InvocationContext {

    private static final ThreadLocal<InvocationContext> HOLDER = new ThreadLocal<>();

    private InvocationNode root;
    private final Deque<InvocationNode> stack = new ArrayDeque<>();

    public static InvocationContext start() {
        InvocationContext ctx = new InvocationContext();
        HOLDER.set(ctx);
        return ctx;
    }

    public static InvocationContext current() {
        return HOLDER.get();
    }

    public static void clear() {
        HOLDER.remove();
    }

    /** 메서드 진입 시 호출 */
    public void push(String methodName) {
        InvocationNode node = new InvocationNode(methodName);
        if (root == null) {
            root = node;
        } else if (!stack.isEmpty()) {
            stack.peek().addChild(node);
        }
        stack.push(node);
    }

    /** 메서드 종료 시 호출 */
    public void pop() {
        if (!stack.isEmpty()) {
            stack.pop().finish();
        }
    }

    public InvocationNode getRoot() { return root; }
    public boolean hasData() { return root != null; }
}
