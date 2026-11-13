# Home news carousel

The static introduction banner on Home is replaced by a separate news carousel.
Admin manages it in **Ban tin trang chu**. Weekly featured trades and the economic
calendar remain separate sections.

## API

All paths have the `/api` prefix.

| Method | Path | Access | Purpose |
| --- | --- | --- | --- |
| GET | `/home-posts` | Public | Active posts, newest created first; no week/date filter |
| GET | `/home-posts/admin` | Admin | Active and hidden home posts |
| POST | `/home-posts` | Admin | Create a post |
| PATCH | `/home-posts/:id` | Admin | Edit or toggle `isActive` |
| DELETE | `/home-posts/:id` | Admin | Delete a post |
| POST | `/home-posts/uploads` | Admin | Upload up to 12 image files, max 10 MB each |

Create example:

```json
{
  "title": "Community announcement",
  "summary": "Optional card summary",
  "coverImageUrl": "",
  "contentBlocks": [
    { "type": "text", "text": "Full article content" },
    { "type": "image", "imageUrl": "https://example.test/chart.webp" }
  ],
  "isActive": true
}
```

At least one nonempty text/image block is required. Cover and summary are
optional; a text-only post uses the app's branded gradient. Content block order
is preserved. The client must not send `placement` or `weekStart`. Optional
fields may be omitted; send an empty string to clear summary/cover, not `null`.
Uploads use multipart field `files` and return `{ "imageUrls": [...] }`.

Posts stay visible until hidden/deleted. Multiple posts auto-advance every five
seconds and support swiping and full-article reading, including for guests.
An empty successful response hides the section rather than rendering demo news.
Home refreshes on resume/tab activation, every 30 seconds while active, and on
pull-to-refresh. During a network failure the repository retains the last
successful in-memory response, including across a week boundary; visibility
changes are reflected after a successful refresh, not while offline.

## Storage and compatibility

- Migration `HomePosts20261113010000` adds `placement` to `featured_trades`.
  Existing rows default to `FEATURED_TRADE` and keep all content/media.
- Home posts use `HOME_POST`; their required legacy `week_start` storage column
  is not used for visibility. Both public/admin endpoints scope reads and
  mutations by placement, so a known ID cannot move/edit/delete another section.
- Home post media uses the `HOME_POST` context and its own Drive folder. Public
  image retrieval reuses `/featured-trades/drive-images/:fileId` and accepts only
  registered editorial image contexts, not private Plan/Journal media.
- Cleanup checks image references across both placements before removing media.
- Rollback refuses to drop the placement column while any home posts exist.

Deploy the API migration before the admin/mobile update. An older API does not
support `/home-posts`; the mobile repository handles that error without crashing
but cannot display news until the new API is deployed. The existing weekly
featured trade routes remain compatible.

## Verification

Jest covers HTTP validation/roles, section isolation, publication lifecycle,
media context routing, and migration preservation/rollback. PostgreSQL tests use
only explicitly supplied disposable database URLs and own temporary schemas:

```sh
HOME_POSTS_TEST_DATABASE_URL=postgres://user@localhost/test_database \
PLAN_TEST_DATABASE_URL=postgres://user@localhost/test_database \
pnpm --dir apps/api test --runInBand
```

Mobile regression tests are in `apps/mobile/test/home_posts_test.dart` and the
existing featured trade suite. They cover the Home replacement, empty refresh,
cross-week offline cache, guest article navigation, swipe/autoplay, and app/tab
lifecycle. Local browser/native test evidence is kept under
`output/test-run/home-posts-20261113/`; it does not establish production deployment
or Google Drive availability.
