# springboot-cicd
Git push → GitHub Actions → Build Docker → Push DockerHub → SSH VPS → Deploy

portainer:
link: https://103.121.90.122:9443
account: admin
mk: Degio......


- Cần tạo foler 
  - mkdir -p /root/app
  ở vps để chứa file jar và file docker-compose.yml, nginx 
  

- Đang sử dụng nginx để làm load balancer