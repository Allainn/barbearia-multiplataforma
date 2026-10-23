FROM maven:3.9-eclipse-temurin-21 AS base
WORKDIR /app

FROM base AS deps
COPY pom.xml .
RUN mvn dependency:go-offline -B

FROM deps AS build
COPY src/ src/
RUN mvn package -DskipTests -B

FROM eclipse-temurin:21-jre AS final
WORKDIR /app
COPY --from=build /app/target/agendamento-service-1.0.0.jar app.jar
EXPOSE 8012
RUN useradd --create-home app
USER app
CMD ["java", "-jar", "app.jar"]
