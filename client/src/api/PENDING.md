# Calls and fields ahead of API.md

The calls in `pending.ts` and the optional fields in `lib/types.ts` below are not in API.md yet. Each one degrades quietly when the server does not have it.

## Amazon export

- `POST /api/v1/sources/kindle_export/request` -> `204`.
- `POST /api/v1/sources/kindle_export/upload`, multipart `archive` (zip) -> `200 { books, highlights }`, `422 invalid_archive`.
- The server answers both with `501 not_implemented` for now. The client treats `501` and `404` as "not available yet" (`notOfferedYet`).
- `Source` for `kindle_export` with `status: "requested"` and `requested_at` shows the waiting state; `status: "ready"` shows "Upload archive". The server cannot store these yet: the `source_connections.status` CHECK constraint allows only `never`, `ok`, `error` and `needs_login`, so `requested` and `ready` need a migration that widens it.

## Optional fields

- `StatsBook.cloth`: without it the year shelf draws the book in `spine-blank`.
- `Stats.listened` and `Stats.read`: without them the summary falls back to `by_format.audio` and `by_format.ebook`.
- `RemoteSession.login_window_seconds` and `created_at`: the sign-in window for the time bar (`login_window_seconds`, else `expires_at - created_at`). Without either, only the countdown is shown.
