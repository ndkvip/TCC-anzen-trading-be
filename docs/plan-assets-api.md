# Asset-scoped trading plans

## Identity and compatibility

A saved Plan is identified by `(userId, symbol, scope, periodKey)`.
`symbol` is trimmed and uppercased, 1-30 ASCII characters matching
`[A-Z0-9][A-Z0-9._/-]*` (for example `XAUUSD`, `BTCUSDT`, `NAS100`, `BTC/USD`).
Invalid or blank values return HTTP 400. `GENERAL` is reserved for legacy plans
without an assigned asset; the UI displays it as "Chưa gán tài sản". Missing
`symbol` on old clients resolves/writes only `GENERAL`, never a named asset.
Existing plan IDs, content, status, media and inheritance references are retained.

## Endpoints (JWT required)

- `PUT /api/plans`: existing fields plus optional `symbol`. Upsert only the
  matching identity. Retries cannot overwrite another asset's plan.
- `GET /api/plans/resolve?scope=DAY&periodKey=2026-11-13&symbol=XAUUSD`:
  return the saved plan or an unsaved `draft-...` with the requested `symbol`.
  Scope remains DAY/WEEK/MONTH; period keys remain date/Monday date/YYYY-MM.
- `GET /api/plans?scope=DAY&symbol=XAUUSD`: optional filters; omitting symbol
  lists all assets including GENERAL. Every row includes `symbol`.
- `DELETE /api/plans/:id`: ownership-scoped, unchanged. Mobile tombstones
  include symbol so a lost PUT response is resolved for the correct asset.
- `GET /api/plans/admin/all?userId=...&symbol=XAUUSD`: admin-only, optional
  symbol filter. Rows include symbol and the existing plan metadata.

New drafts inherit only from the same user AND symbol: week from month; day
from saved week, or month when the week does not exist. No cross-asset or
GENERAL-to-asset inheritance. Inheriting does not modify the source plan.

Example PUT:

```json
{
  "symbol": "NAS100",
  "scope": "DAY",
  "periodKey": "2026-11-13",
  "title": "NAS100 - intraday",
  "status": "DRAFT",
  "contentDelta": [{"insert": "Wait for confirmation\n"}],
  "timeframePairs": ["H4-M15"],
  "imageUrls": []
}
```

## Mobile persistence and rollout

Asset selection changes the active plan, not the asset of an existing plan.
The previous plan is saved before switching; a failed local save prevents the
switch. Library rows show the asset and can open legacy GENERAL plans. Local
files, merge keys, pending deletions, retries and offline inheritance are asset
scoped. GENERAL retains old filenames for non-destructive local compatibility;
legacy single-plan mirrors are recovered before remote loading.

Deploy the API and migration `PlanAssets20261113000000` before releasing the
mobile client. The client requires a matching symbol in named-asset responses;
it must retain pending edits rather than accept an old backend's unscoped reply.
The migration replaces the old user/scope/period uniqueness with asset-scoped
uniqueness. Rollback is refused while any plan has an assigned asset, preventing loss of
asset metadata or collisions in the old identity. This document does not imply production deployment.

## Local verification

- API build and Jest suite: `pnpm --dir apps/api build` and
  `pnpm --dir apps/api test --runInBand`.
- Real PostgreSQL migration tests are opt-in via `PLAN_TEST_DATABASE_URL` and
  create/drop only randomly named test schemas in that explicit test database.
  They cover constraint-only, index-only and combined legacy uniqueness,
  content preservation, new uniqueness and rollback protection.
- Mobile: `flutter analyze --no-pub` and `flutter test --no-pub` from
  `apps/mobile`. Repository HTTP tests use local in-memory transport; widget
  tests cover safe asset transitions, inheritance, legacy library access and
  the selector/custom-symbol dialog on a 320px screen.
