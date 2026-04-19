# README — springboot-cicd

Tài liệu này mô tả chi tiết cách project Spring Boot này được đóng gói, build thành Docker image, và triển khai theo luồng CI/CD (GitHub Actions → Docker Hub → Deploy qua SSH bằng docker-compose). Nó cũng giải thích `Dockerfile`, `docker-compose.yml`, và cung cấp ví dụ `deploy.yml` cho GitHub Actions.

Mục lục
- Giới thiệu ngắn
- Yêu cầu trước
- Luồng CI/CD (tóm tắt)
- Dockerfile (ví dụ + giải thích)
- docker-compose.yml (ví dụ + giải thích)
- Ví dụ GitHub Actions: `deploy.yml`
- Lệnh thường dùng
- Troubleshooting & bảo mật
- Bản đồ nhanh các file trong dự án

---

Giới thiệu
---------
Project: ứng dụng Spring Boot (Java) nhỏ dùng để test CI/CD. Hiện không kết nối database — các API là fake (in-memory) để test CRUD.

Chi tiết từ mã nguồn (`src/`)
-----------------------------
Phần này mô tả chính xác những gì có trong `src/main/java` của project (dựa trên mã hiện tại), các endpoint, cách hoạt động và cách test nhanh.

1) HelloController
- File: `src/main/java/org/example/cicd/controller/HelloController.java`
- Endpoint: GET `/` và `/hello`
- Hành vi:
  - Đọc biến môi trường `INSTANCE_ID` để hiển thị id instance (ví dụ khi chạy nhiều instance trong compose)
  - Ghi log thông tin instance khi có request
  - Trả về chuỗi dạng: `hello word update version 1.0.2 - instance: <INSTANCE_ID>`

Ví dụ curl (nếu chạy cục bộ cổng 8080 hoặc thông qua nginx trên port 80/8081..8083 tuỳ cấu hình):

```bash
curl http://localhost:8080/hello
# hoặc nếu dùng nginx-lb trên port 80
curl http://localhost/
```

2) Todo API (CRUD, in-memory)
- Controller: `src/main/java/org/example/cicd/controller/TodoController.java`
- Service: `src/main/java/org/example/cicd/service/TodoService.java`
- Entity: `src/main/java/org/example/cicd/entity/Todo.java`

Endpoints:
- GET /api/todos
  - Trả về danh sách tất cả Todo (JSON array)
  - Ví dụ:
    curl -s http://localhost:8080/api/todos | jq

- GET /api/todos/{id}
  - Trả về Todo với id tương ứng hoặc 404 nếu không tồn tại
  - Ví dụ:
    curl -i http://localhost:8080/api/todos/1

- POST /api/todos
  - Tạo một Todo mới (server tự gán id)
  - Yêu cầu body JSON: { "title": "Vi du", "completed": false }
  - Trả về 201 Created với header `Location` trỏ đến `/api/todos/{id}` và body là object vừa tạo
  - Ví dụ:

```bash
curl -i -X POST http://localhost:8080/api/todos \
  -H "Content-Type: application/json" \
  -d '{"title":"Mua banh mi","completed":false}'
```

- PUT /api/todos/{id}
  - Cập nhật Todo đã có. Implementation `TodoService.update`:
    - Nếu `title` trong body không null thì sẽ cập nhật title
    - `completed` được gán theo giá trị body (primitive boolean)
  - Nếu id không tồn tại trả về 404
  - Ví dụ:

```bash
curl -i -X PUT http://localhost:8080/api/todos/1 \
  -H "Content-Type: application/json" \
  -d '{"title":"Mua nuoc","completed":true}'
```

- DELETE /api/todos/{id}
  - Xóa Todo với id, trả về 204 nếu xóa thành công, 404 nếu không tồn tại
  - Ví dụ:

```bash
curl -i -X DELETE http://localhost:8080/api/todos/1
```

Lưu ý về lưu trữ dữ liệu:
- `TodoService` dùng `ConcurrentHashMap` và `AtomicLong` để lưu in-memory. Dữ liệu sẽ mất khi ứng dụng/restart container.
- Không có database — phù hợp cho test, demo hoặc unit/integration test nhanh.

Docker Compose hiện tại (`docker-compose.yml`)
-------------------------------------------
File hiện có nằm ở project root và định nghĩa 3 instance của cùng 1 image plus nginx load balancer:

- Services: `app1`, `app2`, `app3`, `nginx`
- Image cho các app: `${DOCKER_USERNAME}/springboot-cicd:${IMAGE_TAG}` (dùng biến môi trường `.env` hoặc export trước khi chạy)
- Port mapping:
  - app1 -> host 8081 -> container 8080
  - app2 -> host 8082 -> container 8080
  - app3 -> host 8083 -> container 8080
- Mỗi app đặt env `INSTANCE_ID` (app1/app2/app3) để `HelloController` trả về và log được instance id (hữu ích khi test load balancing)
- `nginx` service map `./nginx/nginx.conf` để làm reverse proxy / load balancer, listen trên port 80

Ví dụ `.env` (tạo file `.env` ở root trước khi chạy):

```ini
DOCKER_USERNAME=yourdockerhubuser
IMAGE_TAG=latest
```

Chạy local bằng docker-compose (trên máy có Docker):

```bash
# từ thư mục project
export DOCKER_USERNAME=yourdockerhubuser
export IMAGE_TAG=latest
docker-compose up -d
# hoặc nếu có .env file
docker-compose up -d
```

Sau khi chạy, truy cập:
- http://localhost -> nginx load balancer (port 80) -> sẽ forward tới một trong các app instances
- http://localhost:8081 -> instance app1
- http://localhost:8082 -> instance app2
- http://localhost:8083 -> instance app3

Dockerfile (tệp thực tế trong repo)
------------------------------------
Tệp `Dockerfile` trong repo hiện có cấu trúc multi-stage build:

- Stage 1 (build): `maven:3.9.9-eclipse-temurin-17`
  - WORKDIR /app
  - COPY pom.xml .
  - RUN mvn -B dependency:go-offline
  - COPY src ./src
  - RUN mvn -B package -DskipTests
- Stage 2 (runtime): `eclipse-temurin:17-jre-alpine`
  - WORKDIR /app
  - COPY --from=build /app/target/*.jar app.jar
  - ENTRYPOINT ["java", "-jar", "app.jar"]

Ghi chú từ Dockerfile thực tế:
- Triển khai `dependency:go-offline` để tận dụng cache cho dependencies (tốc độ build tốt hơn khi pom không thay đổi)
- Runtime dùng Alpine JRE (nhỏ, nhẹ)
- Hiện ENTRYPOINT chạy `java -jar app.jar` trực tiếp — nếu muốn cấu hình bộ nhớ, có thể bổ sung `ENV JAVA_OPTS` và đổi ENTRYPOINT sang `sh -c "java $JAVA_OPTS -jar app.jar"`.

Hướng dẫn test nhanh (local)
----------------------------
1) Build và chạy ứng dụng không Docker (nhanh để dev):

```bash
./mvnw spring-boot:run
# truy cập http://localhost:8080/hello
```

2) Build jar và chạy jar:

```bash
./mvnw clean package
java -jar target/cicd-0.0.1-SNAPSHOT.jar
```

3) Chạy bằng Docker (nếu đã build/push image hoặc build local):

```bash
# build local image
docker build -t yourdockerhubuser/springboot-cicd:local .
# chạy single instance
docker run --rm -p 8080:8080 yourdockerhubuser/springboot-cicd:local
```

4) Chạy multi-instance với nginx load balancer (sử dụng docker-compose.yml có sẵn):

```bash
# từ thư mục project, export biến env hoặc tạo .env
export DOCKER_USERNAME=yourdockerhubuser
export IMAGE_TAG=local
docker-compose up -d
# kiểm tra
curl http://localhost/hello
curl http://localhost:8081/hello
curl http://localhost:8082/hello
```

Các phần khác trong README (CI/CD, deploy.yml, troubleshooting) vẫn giữ nguyên nhưng lưu ý rằng workflow và docker-compose nên dùng cùng tên image (`${DOCKER_USERNAME}/springboot-cicd`) và tag (`${IMAGE_TAG}`) như trong `docker-compose.yml`.
