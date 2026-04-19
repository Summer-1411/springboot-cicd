# =========================
# 1. BUILD STAGE
# =========================
# Dùng image Maven + JDK 17 để build project
FROM maven:3.9.9-eclipse-temurin-17 AS build

# Set thư mục làm việc trong container
WORKDIR /app

# Copy file pom.xml trước
# 👉 mục đích: tận dụng cache Docker layer
# nếu pom không đổi thì dependency không bị tải lại
COPY pom.xml .

# Tải toàn bộ dependency về local (.m2)
# -B = batch mode (non-interactive, dùng cho CI/CD)
# 👉 không hỏi input, log gọn hơn, build nhanh hơn
RUN mvn -B dependency:go-offline

# Copy source code vào container
COPY src ./src

# Build project -> tạo file .jar trong /target
# -B = batch mode (giống trên)
# -DskipTests = bỏ qua test (build nhanh hơn)
RUN mvn -B package -DskipTests


# =========================
# 2. RUNTIME STAGE
# =========================
# Dùng JRE nhẹ hơn (không cần JDK)
FROM eclipse-temurin:17-jre-alpine

# Thư mục chạy app
WORKDIR /app

# Copy file jar từ stage build sang
COPY --from=build /app/target/*.jar app.jar

# ENTRYPOINT = lệnh mặc định khi container start
# 👉 khác CMD ở chỗ:
# - ENTRYPOINT: luôn chạy (khó override)
# - CMD: có thể bị override khi docker run

# Các option JVM:
# -Xms256m = RAM khởi tạo (initial heap)
# -Xmx512m = RAM tối đa (max heap)
# 👉 giúp tránh app ăn hết RAM VPS

ENTRYPOINT ["java", "-jar", "app.jar"]
#ENTRYPOINT ["java","-Xms256m","-Xmx512m","-jar","app.jar"]