package com.jvisualizer.example.track;

import java.util.ArrayList;
import java.util.List;

/**
 * 단일 메서드 호출 정보를 담는 트리 노드
 */
public class InvocationNode {

    private final String name;
    private final long startMs;
    private long endMs;
    private final List<InvocationNode> children = new ArrayList<>();

    public InvocationNode(String name) {
        this.name = name;
        this.startMs = System.currentTimeMillis();
    }

    public void finish() {
        this.endMs = System.currentTimeMillis();
    }

    public long getDurationMs() {
        return endMs > 0 ? endMs - startMs : System.currentTimeMillis() - startMs;
    }

    public void addChild(InvocationNode child) {
        children.add(child);
    }

    public String getName() { return name; }
    public List<InvocationNode> getChildren() { return children; }

    /** Flutter에서 렌더링할 JSON 트리 */
    public String toJson() {
        String shortName = name;
        String[] parts = name.split("\\.");
        if (parts.length > 2) {
            shortName = parts[parts.length - 2] + "." + parts[parts.length - 1];
        }

        StringBuilder sb = new StringBuilder();
        sb.append("{\"name\":\"").append(shortName.replace("\"", "'")).append("\"");
        sb.append(",\"full_name\":\"").append(name.replace("\"", "'")).append("\"");
        sb.append(",\"duration_ms\":").append(getDurationMs());

        if (!children.isEmpty()) {
            sb.append(",\"children\":[");
            for (int i = 0; i < children.size(); i++) {
                if (i > 0) sb.append(",");
                sb.append(children.get(i).toJson());
            }
            sb.append("]");
        }
        sb.append("}");
        return sb.toString();
    }

    /** 텍스트 트리 (adonistrack 스타일) */
    public String toText(int depth, long rootDuration) {
        String indent = "  ".repeat(depth);
        double pct = rootDuration > 0 ? getDurationMs() * 100.0 / rootDuration : 0;
        StringBuilder sb = new StringBuilder();
        sb.append(String.format("%s→ %s (%dms / %.1f%%)\n",
                indent, name, getDurationMs(), pct));
        for (InvocationNode child : children) {
            sb.append(child.toText(depth + 1, rootDuration));
        }
        return sb.toString();
    }
}
