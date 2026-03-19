# 🔍 J-Visualizer — 실시간 Java 애플리케이션 성능 분석 시스템

> JVM 기반 애플리케이션의 CPU · Memory · Thread · SQL을 실시간 모니터링하고,
> 병목 현상을 시각화하여 최적화 가이드를 제공합니다.

---

## � 스크린샷

### Dashboard
![Dashboard](screenCaptures/01.dahboard.png)

### Flame Graph
![Flame Graph](screenCaptures/02.flame-graph.png)

### Call Tree
![Call Tree](screenCaptures/03.call-tree.png)

### Methods
![Methods](screenCaptures/04.methods.png)

### Threads
![Threads](screenCaptures/05.threads.png)

### SQL Profile
![SQL Profile](screenCaptures/06.sql-profile.png)

### Request History
![Request History](screenCaptures/07.request-history.png)

---

## �📁 프로젝트 구조

```
j-visualizer/
├── docs/                            # 📊 Mermaid 다이어그램 산출물
│   ├── 01_system_architecture.md   # 전체 아키텍처 + 데이터 플로우
│   ├── 02_component_diagram.md     # 클래스 다이어그램
│   ├── 03_data_schema_api.md       # ER 다이어그램 + REST API
│   ├── 04_deployment_diagram.md    # 배포 구성 + Docker Compose
│   ├── 05_ui_flow.md               # Flutter 화면 플로우
│   ├── 06_invocation_tracking.md   # Requests 탭 설계 (신규)
│   └── 07_sql_profiling.md         # SQL Profiling 설계 (신규)
│
├── java-agent/                      # ☕ Java Agent (-javaagent 주입)
│   ├── AgentMain.java               # premain/agentmain 진입점
│   ├── AgentConfig.java             # 파라미터 파싱
│   ├── ProfilingOrchestrator.java   # 전체 조율 + 스케줄링
│   ├── DataSender.java              # HTTP 비동기 전송
│   ├── cpu/CpuProfiler.java         # Sampling + FlameGraph 빌드
│   ├── memory/MemoryProfiler.java   # MXBean Heap/GC 수집
│   ├── thread/ThreadProfiler.java   # Thread Dump + Deadlock
│   └── sql/SqlProfiler.java         # ASM JDBC 인터셉터
│
├── backend/                         # 🖥️ Spring Boot Backend
│   ├── controller/ProfilerController.java      # REST API
│   ├── controller/InvocationController.java    # 요청 트리 API (신규)
│   ├── websocket/ProfilerWebSocketHandler.java # WS broadcast
│   ├── service/ProfilingDataService.java       # 핵심 로직
│   ├── model/                       # JPA 엔티티
│   └── repository/                  # Spring Data JPA
│
├── flutter-dashboard/               # 📱 Flutter 대시보드
│   └── lib/
│       ├── screens/
│       │   ├── dashboard_tab.dart   # 실시간 차트
│       │   ├── flame_graph_tab.dart # Flame Graph + 히스토리
│       │   ├── call_tree_tab.dart   # Call Tree + 히스토리 + Highlight
│       │   ├── method_list_tab.dart # 메서드 목록
│       │   ├── thread_tab.dart      # Thread 상태
│       │   ├── sql_tab.dart         # SQL 이벤트
│       │   └── invocation_tab.dart  # 요청별 호출 트리 (신규)
│       └── widgets/
│
├── example-app/                     # 🧪 테스트용 Spring Boot 앱
│   └── src/main/java/com/jvisualizer/example/
│       ├── controller/TestController.java  # 테스트 시나리오
│       ├── service/OrderService.java       # 6가지 병목 시나리오
│       ├── sql/
│       │   ├── SqlCapture.java             # Hibernate StatementInspector (신규)
│       │   └── SqlProfilingAspect.java     # AOP SQL 캡처 (신규)
│       └── track/
│           ├── InvocationNode.java         # 호출 트리 노드 (신규)
│           ├── InvocationContext.java      # ThreadLocal 컨텍스트 (신규)
│           ├── TrackAspect.java            # AOP 호출 추적 (신규)
│           └── TrackConfig.java            # Filter + Jackson 직렬화 (신규)
│
├── ISSUE-2026-03-19.md              # 📋 개발 이슈 로그
├── docker-compose.yml
└── README.md
```

---

## 🚀 빠른 시작

### Docker Compose (권장)

```bash
# 1. java-agent 빌드 (Docker volume mount용)
cd java-agent && mvn package -DskipTests && cd ..

# 2. 전체 스택 실행
docker compose up --build

# 서비스 확인
# Backend API:   http://localhost:8080/api/status
# Example App:   http://localhost:8090/test
```

### Flutter Dashboard 실행

```bash
cd flutter-dashboard
flutter pub get
flutter create . --platforms=windows,web   # 최초 1회
flutter run -d windows                     # Windows Desktop
flutter run -d web-server --web-port=7777  # Web Browser
```

---

## 🧪 테스트 시나리오

| 엔드포인트                                     | 시나리오           | Dashboard 확인 탭                    |
|:----------------------------------------- |:-------------- |:--------------------------------- |
| `GET /test/cpu-intensive?iterations=2000` | CPU 집약 작업      | **Flame Graph**, **Call Tree**    |
| `GET /test/memory-leak?mb=50`             | 메모리 누수         | **Dashboard** — Heap 상승           |
| `GET /test/memory-release`                | 메모리 해제         | **Dashboard** — Heap 하락           |
| `GET /test/slow-sql`                      | N+1 + LIKE 풀스캔 | **SQL** — Slow Query 빨간 표시        |
| `GET /test/thread-contention?threads=20`  | 락 경합           | **Threads** — BLOCKED 상태          |
| `GET /test/deadlock`                      | Deadlock       | **Threads** — DEADLOCK 감지 + Alert |
| `GET /test/full-load`                     | 모든 시나리오        | **Requests** — 전체 호출 트리           |

---

## 📱 Flutter 대시보드 탭 설명

| 탭               | 기능                                        |
|:--------------- |:----------------------------------------- |
| **Dashboard**   | 실시간 Heap/Thread 라인 차트, Thread 상태 파이차트     |
| **Flame Graph** | CPU 샘플링 시각화, 히스토리 드롭다운으로 과거 조회            |
| **Call Tree**   | 계층 호출 트리, Highlight 패키지 강조, 히스토리 조회       |
| **Methods**     | Self/Total Time 정렬 테이블                    |
| **Threads**     | BLOCKED 강조, Stack Trace 확장, Deadlock 표시   |
| **SQL**         | 실제 SQL 쿼리 표시, Slow Query 필터, 상세 패널        |
| **Requests**    | HTTP 요청별 전체 호출 트리 저장/조회 (adonistrack 스타일) |

---

## ⚙️ Agent 파라미터

```
-javaagent:j-visualizer-agent-all.jar=<key>=<value>,...
```

| 파라미터               | 기본값                     | 설명                           |
|:------------------ |:----------------------- |:---------------------------- |
| `server`           | `http://localhost:8080` | Backend 서버 URL               |
| `mode`             | `sampling`              | `sampling` / `instrumenting` |
| `interval`         | `10`                    | Sampling 주기 (ms)             |
| `package`          | `""` (전체)               | 집중 분석할 패키지 prefix            |
| `flushInterval`    | `5000`                  | Flame Graph 전송 주기 (ms)       |
| `sqlProfiling`     | `true`                  | SQL Profiling 활성화            |
| `slowSqlThreshold` | `1000`                  | Slow SQL 기준 (ms)             |

---

## 🔌 REST API 명세

### Agent → Backend

| Method | Path                  | 설명                 |
|:------ |:--------------------- |:------------------ |
| POST   | `/api/agent/register` | Agent 등록           |
| POST   | `/api/metrics`        | JVM 메트릭 (1초)       |
| POST   | `/api/profile`        | CPU Flame Graph    |
| POST   | `/api/threads`        | Thread Dump        |
| POST   | `/api/sql`            | SQL 이벤트            |
| POST   | `/api/invocations`    | HTTP 요청 호출 트리 (신규) |

### Frontend → Backend

| Method | Path                              | 설명               |
|:------ |:--------------------------------- |:---------------- |
| GET    | `/api/status`                     | 서버 상태            |
| GET    | `/api/metrics/history?minutes=10` | 메트릭 이력           |
| GET    | `/api/profile/latest`             | 최신 프로파일          |
| GET    | `/api/profile/history`            | 프로파일 히스토리 목록     |
| GET    | `/api/threads/latest`             | 최신 Thread Dump   |
| GET    | `/api/sql/events`                 | SQL 이벤트 100건     |
| GET    | `/api/sql/stats`                  | SQL 통계           |
| GET    | `/api/bottlenecks`                | 병목 분석 리포트        |
| GET    | `/api/invocations`                | 요청 호출 트리 목록 (신규) |
| GET    | `/api/invocations/{id}`           | 특정 요청 상세 (신규)    |
| DELETE | `/api/invocations`                | 이력 전체 삭제 (신규)    |

### WebSocket `ws://host/ws/dashboard`

| 메시지 타입        | 설명                 |
|:------------- |:------------------ |
| `METRICS`     | JVM 실시간 메트릭        |
| `CPU_PROFILE` | Flame Graph 데이터    |
| `SQL_EVENT`   | SQL 실행 이벤트         |
| `THREAD_DUMP` | Thread 스냅샷         |
| `INVOCATION`  | HTTP 요청 호출 트리 (신규) |
| `ALERT`       | 이상 감지 알림           |

---

## 📊 개발 산출물 (docs/)

| 파일                          | 내용                                |
|:--------------------------- |:--------------------------------- |
| `01_system_architecture.md` | 전체 시스템 구성도, 데이터 플로우               |
| `02_component_diagram.md`   | Agent/Backend/Flutter 클래스 다이어그램   |
| `03_data_schema_api.md`     | ER 다이어그램, API 그래프, WebSocket 상태도  |
| `04_deployment_diagram.md`  | Docker Compose, CI/CD 파이프라인       |
| `05_ui_flow.md`             | Flutter 화면 전환, Flame Graph 알고리즘   |
| `06_invocation_tracking.md` | Requests 탭 시퀀스, ThreadLocal 트리 구조 |
| `07_sql_profiling.md`       | SQL 캡처 흐름, StatementInspector 구조  |

---

## 🛠️ 기술 스택

| 레이어            | 기술                                              |
|:-------------- |:----------------------------------------------- |
| **Java Agent** | Java 17 Instrumentation API, ASM 9.6, MXBean    |
| **Backend**    | Spring Boot 3.2, WebSocket, Spring Data JPA, H2 |
| **Frontend**   | Flutter 3.x, fl_chart, Provider, http           |
| **SQL 추적**     | Hibernate StatementInspector, Spring AOP        |
| **호출 추적**      | Spring AOP + ThreadLocal InvocationContext      |
| **컨테이너**       | Docker, Docker Compose (멀티스테이지 빌드)              |

---

## 📋 이슈 로그

- [ISSUE-2026-03-19.md](./ISSUE-2026-03-19.md) — 초기 개발 세션 이슈 13건 + 신규 기능 4건
