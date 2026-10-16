#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API_LOG="${ROOT_DIR}/.local-api.log"
ADMIN_LOG="${ROOT_DIR}/.local-admin.log"

cleanup() {
  local status=$?
  trap - EXIT INT TERM
  [[ -n "${API_PID:-}" ]] && kill "${API_PID}" 2>/dev/null || true
  [[ -n "${ADMIN_PID:-}" ]] && kill "${ADMIN_PID}" 2>/dev/null || true
  wait "${API_PID:-}" 2>/dev/null || true
  wait "${ADMIN_PID:-}" 2>/dev/null || true
  exit "$status"
}
trap cleanup EXIT INT TERM

cd "${ROOT_DIR}"

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker chưa được cài đặt hoặc chưa có trong PATH."
  exit 1
fi

if [[ ! -f "${ROOT_DIR}/apps/api/.env" ]]; then
  cp "${ROOT_DIR}/apps/api/.env.example" "${ROOT_DIR}/apps/api/.env"
fi
if [[ ! -f "${ROOT_DIR}/apps/admin/.env.local" ]]; then
  cp "${ROOT_DIR}/apps/admin/.env.example" "${ROOT_DIR}/apps/admin/.env.local"
fi

echo "Khởi động PostgreSQL bằng Docker..."
docker compose up -d postgres

for _ in {1..30}; do
  if docker compose exec -T postgres pg_isready -U ttc_ict -d ttc_ict >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
if ! docker compose exec -T postgres pg_isready -U ttc_ict -d ttc_ict >/dev/null 2>&1; then
  echo "PostgreSQL chưa sẵn sàng sau 30 giây."
  exit 1
fi

echo "Chạy migration nền..."
pnpm --dir apps/api migration:run

: >"${API_LOG}"
: >"${ADMIN_LOG}"
(
  pnpm --dir apps/api start:dev >>"${API_LOG}" 2>&1
) &
API_PID=$!
(
  pnpm --dir apps/admin dev >>"${ADMIN_LOG}" 2>&1
) &
ADMIN_PID=$!

for _ in {1..30}; do
  if curl -fsS http://localhost:3001/api/health >/dev/null 2>&1 && curl -fsS http://localhost:3000 >/dev/null 2>&1; then
    echo "ANZEN TRADING local đang chạy:"
    echo "- API:   http://localhost:3001/api"
    echo "- Health: http://localhost:3001/api/health"
    echo "- Admin: http://localhost:3000"
    echo "- Log API:   ${API_LOG}"
    echo "- Log Admin: ${ADMIN_LOG}"
    echo "Nhấn Ctrl+C để dừng API và Admin (PostgreSQL vẫn giữ trong Docker)."
    wait
  fi
  if ! kill -0 "$API_PID" 2>/dev/null || ! kill -0 "$ADMIN_PID" 2>/dev/null; then
    echo "Một service local đã dừng. Kiểm tra log:"
    echo "- ${API_LOG}"
    echo "- ${ADMIN_LOG}"
    exit 1
  fi
  sleep 1
done

echo "Chờ API/Admin khởi động quá thời gian. Kiểm tra log:"
echo "- ${API_LOG}"
echo "- ${ADMIN_LOG}"
exit 1
