# build stage
FROM maven:3.9.9-eclipse-temurin-17 AS build

WORKDIR /app

# copy pom trước để cache dependency
COPY pom.xml .
RUN mvn dependency:go-offline

# rồi mới copy source
COPY src ./src

RUN mvn clean package -DskipTests

# run stage
FROM eclipse-temurin:17-jre-jammy

WORKDIR /app

COPY --from=build /app/target/*.jar app.jar

ENTRYPOINT ["java", "-jar", "app.jar"]