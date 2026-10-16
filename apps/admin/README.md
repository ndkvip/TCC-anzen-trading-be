# ANZEN TRADING Admin Web

Trang quản trị Next.js cho ANZEN TRADING. Admin Web dung chung API va PostgreSQL voi mobile va duoc deploy tren Railway.

## Chay local

```bash
pnpm dev
```

Mo `http://localhost:3000`.

## Build production

```bash
pnpm build
pnpm start
```

Railway se cung cap bien `PORT` cho lenh start.

## Bien moi truong

Dat `NEXT_PUBLIC_API_BASE_URL` den API Railway, vi du:

```env
NEXT_PUBLIC_API_BASE_URL=https://<api-domain>/api
```

## Pham vi admin

- Quan ly tai khoan hoc vien va role `basic` / `advanced`.
- Quan ly noi dung Kien thuc, bai tap va media.
- Duyet media Google Drive dung chung cho Knowledge, Journal va Plan.
- Tra cuu du lieu Journal, Plan va check-in theo quyen.
- Khong quan ly noi dung Trang chu; Trang chu la static content trong mobile.
