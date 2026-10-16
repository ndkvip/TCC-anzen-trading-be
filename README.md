# ANZEN TRADING

Monorepo cho ứng dụng học tập, plan giao dịch, nhật ký và wellbeing ANZEN TRADING.

## Pham vi san pham hien tai

- `apps/mobile`: Flutter app voi 5 tab Trang chu, Kien thuc, Nhat ky giao dich, Plan giao dich va Ca nhan.
- `apps/api`: NestJS API + PostgreSQL cho authentication, phan quyen, noi dung hoc tap, Journal, Plan, check-in, sync va media metadata.
- `apps/admin`: Next.js admin dashboard chạy local trong giai đoạn phát triển.
- Trang chu la static content dong goi trong mobile; admin khong quan ly noi dung Trang chu.
- Google Drive là kho lưu trữ và duyệt media dùng chung; user upload hình từ Journal/Plan qua API local.
- Mobile cache offline ca noi dung bai hoc, media, Journal, Plan va check-in.
- Authentication la luong that: dang ky/dang nhap bang email, xac minh dang ky bang OTP email, refresh token, dang xuat, quen/dat lai/doi mat khau bang email va gioi han mot thiet bi dang hoat dong.
- Tai khoan moi mac dinh la `Thuong`; Admin Web cap `VIP 1` hoac `VIP 2` thu cong, khong co thanh toan/subscription trong pham vi hien tai.
- `Thuong` duoc hoc thu 3 bai Co ban + 1 bai Nang cao; `VIP 1` hoc full Co ban + 3 bai Nang cao; `VIP 2` hoc full.
- Nhat ky co 2 subtab `Intra day` va `Swing`; Intra day co calendar, PNL/So R va tong ket ngay/tuan/thang, Swing la list khong calendar.
- Diem danh dung local notification luc 07:00 theo gio thiet bi, tong diem 0-10 va luu toi da 30 ngay/user.

## Yeu cau moi truong

- Node.js 20+
- pnpm 10+
- Flutter 3.38+
- PostgreSQL 16 hoac Docker

## Phase 1 - Nền tảng local

Phase 1 tập trung dựng và kiểm tra khung chạy local, chưa triển khai Railway:

- PostgreSQL chạy bằng Docker Compose.
- API NestJS chạy tại cổng `3001`, có migration và health check kiểm tra cả database.
- Admin Next.js chạy tại cổng `3000`.
- Mobile Flutter kết nối API qua `API_BASE_URL`.
- Railway chỉ được cấu hình khi release production.

## Chạy local

### 1. Khởi động toàn bộ stack (khuyến nghị)

```bash
pnpm dev:local
```

Script sẽ tự khởi động PostgreSQL bằng Docker, chạy migration, khởi động API/Admin và kiểm tra:

- `http://localhost:3001/api/health`
- `http://localhost:3000`

Nhấn `Ctrl+C` để dừng API/Admin; container PostgreSQL vẫn được giữ lại để lần sau khởi động nhanh hơn.

### 2. PostgreSQL thủ công

```bash
docker compose up -d postgres
```

Nếu máy không chạy Docker, có thể dùng PostgreSQL local và thay `DATABASE_URL` trong `apps/api/.env`. Workspace hiện đã có PostgreSQL local tại cổng 5432.

### 3. Backend

```bash
cp apps/api/.env.example apps/api/.env
# Giữ DATABASE_SYNCHRONIZE=false; API sẽ tự chạy migration local khi khởi động.
pnpm dev:api
```

API mặc định chạy tại `http://localhost:3001/api`. Endpoint `GET /api/health` trả trạng thái API và PostgreSQL. Tài khoản admin được tạo tự động từ `ADMIN_EMAIL` và `ADMIN_PASSWORD` ở lần chạy đầu. Khi chưa cấu hình SMTP, OTP local được log trong terminal vì `AUTH_EXPOSE_OTP=true`.

### 4. Admin

```bash
cp apps/admin/.env.example apps/admin/.env.local
pnpm dev:admin
```

Admin chay tai `http://localhost:3000`.

### 5. Flutter app

Android emulator:

```bash
cd apps/mobile
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3001/api
```

iOS simulator:

```bash
cd apps/mobile
flutter run --dart-define=API_BASE_URL=http://localhost:3001/api
```

Với thiết bị thật, thay host bằng IP LAN của máy chạy backend.

## Bien moi truong backend

| Bien | Muc dich |
| --- | --- |
| `DATABASE_URL` | Chuỗi kết nối PostgreSQL local |
| `DATABASE_SSL` | Đặt `false` cho PostgreSQL local |
| `DATABASE_SYNCHRONIZE` | Đặt `false`; schema được quản lý bằng migration |
| `DATABASE_MIGRATIONS_RUN` | `true` để API tự chạy migration khi khởi động local |
| `JWT_ACCESS_SECRET` | Secret rieng cho access token |
| `JWT_REFRESH_SECRET` | Secret rieng cho refresh token |
| `ADMIN_EMAIL` | Email admin khoi tao |
| `ADMIN_PASSWORD` | Mat khau admin khoi tao, can doi sau lan dang nhap dau |
| `ADMIN_ORIGIN` | Domain admin duoc phep goi API |
| `ADMIN_RESET_URL` | URL trang reset password cua admin |
| `SMTP_*` | SMTP gui email quen mat khau |
| `GOOGLE_DRIVE_*` | Credentials, folder id va cau hinh Google Drive media |

## Deploy demo miễn phí

Bản demo dùng 3 dịch vụ:

- **Render Static Site**: host Admin Web.
- **Render Free Web Service**: host API NestJS. Dịch vụ có thể ngủ sau 15 phút không có request nên request đầu tiên có thể chậm khoảng một phút.
- **Neon Free**: PostgreSQL dùng chung cho API. Google Drive vẫn là nơi lưu media, không lưu ảnh trên filesystem của Render.

Cấu hình đã chuẩn bị trong `render.yaml`. Khi deploy trên Render, chọn **New Blueprint** và trỏ tới repository có file này. Sau đó điền các biến `sync: false`, đặc biệt là `DATABASE_URL`, JWT secrets, thông tin admin, Brevo và Google Drive.

Brevo được gọi qua HTTPS API để gửi OTP/reset password; không dùng SMTP port trên Render Free. Đặt `BREVO_API_KEY`, `BREVO_SENDER_EMAIL` và `BREVO_SENDER_NAME` trong API service.

Neon Free hiện phù hợp cho demo nhỏ; cần theo dõi giới hạn compute/storage trước khi đưa cho nhiều người dùng thật. Render Postgres Free không được chọn vì database miễn phí của Render có thời hạn, còn Neon phù hợp hơn cho bản demo kéo dài.

Sau khi tạo xong hai URL Render, đặt `NEXT_PUBLIC_API_BASE_URL=https://<api-domain>/api` cho Admin và `ADMIN_ORIGIN=https://<admin-domain>` cho API.

## Trạng thái hạ tầng hiện tại

Phase 1 chưa cấu hình Railway và chưa phát sinh chi phí cloud; PostgreSQL, API và Admin đang chạy local để phát triển và kiểm thử. Khi có kế hoạch release production, sẽ bổ sung cấu hình Railway riêng, không ảnh hưởng môi trường local.

Google Drive và SMTP chỉ cần điền credential khi bắt đầu tích hợp dịch vụ thật. Trong local, SMTP có thể để trống để kiểm thử OTP qua log terminal.

## Kiem tra

```bash
pnpm build:api
pnpm build:admin
pnpm lint
pnpm test
```
