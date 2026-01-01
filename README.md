# Secure API Gateway with Cryptographic Enforcement  
**Kong + Keycloak + FastAPI**

Đồ án này triển khai một mô hình **Secure API Gateway** nhằm bảo vệ các backend API bằng các cơ chế xác thực và ủy quyền hiện đại. Hệ thống được xây dựng xoay quanh **Keycloak** đóng vai trò **Identity Provider (OAuth2/OpenID Connect)**, **Kong Gateway (OSS)** làm **API Gateway** chịu trách nhiệm cưỡng chế các chính sách bảo mật, và **FastAPI** là backend service được triển khai phía sau gateway. Đồ án được thực hiện trong khuôn khổ môn học **NT219 – Cryptography**, tập trung vào việc áp dụng các nguyên lý mật mã và bảo mật trong một kiến trúc API thực tế.

Ý tưởng cốt lõi của đồ án là **tập trung hóa bảo mật tại tầng API Gateway**. Client không bao giờ truy cập trực tiếp vào backend service. Thay vào đó, mọi request đều phải đi qua Kong, nơi access token được xác thực bằng cách sử dụng **OAuth2 Client Credentials flow** kết hợp với **Token Introspection** thông qua Keycloak. Thiết kế này cho phép quản lý xác thực tập trung, hỗ trợ thu hồi token và đảm bảo sự phân tách rõ ràng giữa quản lý danh tính, cưỡng chế bảo mật tại gateway và logic ứng dụng.

---

## Tổng quan kiến trúc

Hệ thống tuân theo mô hình API Gateway tiêu chuẩn:

Client → Kong API Gateway → Backend API  
             │  
             └── Token Introspection → Keycloak

Trước tiên, client sẽ lấy **access token** từ Keycloak. Khi gọi API, client gửi request đến Kong kèm theo token. Kong xác thực token bằng cách gọi endpoint `/token/introspect` của Keycloak. Chỉ khi token hợp lệ và đang hoạt động thì request mới được forward đến backend. Backend service không triển khai logic xác thực và hoàn toàn tin tưởng gateway trong việc cưỡng chế bảo mật.

---

## Các thành phần chính

- **Keycloak**: Identity Provider sử dụng OAuth2/OpenID Connect, chịu trách nhiệm cấp và quản lý access token  
- **Kong Gateway (OSS)**: API Gateway thực hiện xác thực và ủy quyền thông qua token introspection  
- **FastAPI**: Backend API service được bảo vệ bởi gateway  
- **Docker Compose**: Công cụ dùng để triển khai và chạy toàn bộ hệ thống trong môi trường local một cách tái lập

---

## Yêu cầu môi trường

- Docker  
- Docker Compose  
- Bash shell (khuyến nghị Linux, macOS hoặc WSL)

---

## Khởi chạy hệ thống

Khởi động toàn bộ hệ thống bằng Docker Compose:

```bash
cd infra
docker compose up -d
```

## Truy cập qua Gateway
 
Tạo một terminal mới sau đó chạy lệnh
``` bash
./clients/call_api.sh
``` 
Để lấy access token từ Keycloak theo OAuth2 Client Credentials flow, sau đó gửi request đã được xác thực đến API thông qua Gateway.

Kiểm tra kết quả trả về từ API. Nếu hệ thống hoạt động đúng, Gateway sẽ xác thực access token bằng cơ chế `Token Introspection` thông qua Keycloak, sau đó forward request đến backend FastAPI và trả về phản hồi `HTTP/1.1 200 OK` kèm thông báo xác thực thành công.

Để kiểm chứng rằng API Gateway không thể bị bypass, người dùng có thể thử gọi API mà không gửi access token hoặc gửi token không hợp lệ thông qua Gateway. Trong các trường hợp này, request phải bị từ chối với mã lỗi 401 hoặc 403. Ngoài ra, khi cố gắng gọi trực tiếp vào backend service, bỏ qua Gateway, request cũng phải bị từ chối hoặc không thể truy cập được. Điều này cho thấy backend API được bảo vệ hoàn toàn phía sau Gateway.

## Triển khai service cá nhân
Bước 1:
- Đặt code service vào `services/my-service/`
- Service lắng nghe trong container ở một port nội bộ, ví dụ `8001`   

Bước 2:

Thêm service vào `infra/docker-compose-yml`

Ví dụ:
``` yaml
services:
  my-service:
    build: ../services/my-service
    container_name: my-service
    environment:
      - PORT=8001
    expose:
      - "8001"
    networks:
      - demo-net
```

Bước 3: 

Khai báo route/service trong Kong (`gateway-config/kong.yml`)

Ví dụ:
``` yaml
services:
  - name: my-service
    url: http://my-service:8001
    routes:
      - name: my-service-route
        paths:
          - /my
        strip_path: true
```

Bước 4:

Thực hiện:
1. Truy cập Keycloak Admin tại `http://localhost:8080` và đăng nhập bằng tài khoản admin.
2. Chọn realm `secure`.
3. Vào mục **Clients** và tạo một client mới.
4. Đặt `Client ID` theo ý muốn (ví dụ: `my-service-client`).
5. Chọn **Client type = Confidential** và bật **Service Accounts** để sử dụng Client Credentials flow.
6. Sau khi tạo client, vào tab **Credentials** để lấy `client_secret`.

Gắn plugin bảo mật cho route/service mới vào file `Kong.yml`.

Ví dụ:
``` yaml
plugins:
  - name: oauth2-introspection
    route: my-service-route
    config:
      introspection_endpoint: http://keycloak:8080/realms/secure/protocol/openid-connect/token/introspect
      client_id: api-client
      client_secret: api-secret
      token_type_hint: access_token
```