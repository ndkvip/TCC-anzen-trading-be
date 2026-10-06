# ANZEN TRADING Backend

NestJS API + PostgreSQL backend for ANZEN TRADING.

## Local

```bash
cp .env.example .env
pnpm install
pnpm start:dev
```

## Render demo

`render.yaml` contains the Render Free Web Service configuration. Use Neon PostgreSQL for `DATABASE_URL`, set `DATABASE_SSL=true`, and set all secret variables in the Render dashboard. Brevo HTTPS API is used for OTP/reset emails because Render Free blocks outbound SMTP ports. Google Drive remains the canonical media store.

Health check: `/api/health`
