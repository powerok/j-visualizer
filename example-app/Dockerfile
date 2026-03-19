# Stage 1: agent 빌드
FROM maven:3.9.6-eclipse-temurin-17 AS agent-build
WORKDIR /agent
COPY java-agent/pom.xml .
COPY java-agent/src ./src
RUN mvn package -DskipTests -q

# Stage 2: example-app 빌드
FROM maven:3.9.6-eclipse-temurin-17 AS app-build
WORKDIR /app
COPY example-app/pom.xml .
COPY example-app/src ./src
RUN mvn package -DskipTests -q

# Stage 3: 실행
FROM eclipse-temurin:17-jre-jammy
WORKDIR /app
COPY --from=agent-build /agent/target/j-visualizer-agent-all.jar agent.jar
COPY --from=app-build /app/target/*.jar app.jar

EXPOSE 8090
ENTRYPOINT ["java", "-jar", "app.jar"]
