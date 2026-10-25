# Calls and fields ahead of API.md

The calls in `pending.ts` and the optional fields in `lib/types.ts` below are not in API.md yet. Each one degrades quietly when the server does not have it.

## Litres sign in and Amazon export

- `POST /api/v1/sources/litres/sync` `{ login, password }` -> `200 { books, highlights }`. `422` carries `field` (`login` or `password`) and a code translated through `sourceErrors.<code>`; `422 captcha_required` opens the Litres captcha flow (`/sources/litres/captcha`). The password is sent once and never stored.
- `POST /api/v1/sources/kindle_export/request` -> `204`.
- `POST /api/v1/sources/kindle_export/upload`, multipart `archive` (zip) -> `200 { books, highlights }`, `422 invalid_archive`.
- The server answers all three with `501 not_implemented` for now. The client treats `501` and `404` as "not available yet" (`notOfferedYet`) and keeps the typed password.
- `Source` for `kindle_export` with `status: "requested"` and `requested_at` shows the waiting state; `status: "ready"` shows "Upload archive".

## Optional fields

- `StatsBook.cloth`: without it the year shelf draws the book in `spine-blank`.
- `Stats.listened` and `Stats.read`: without them the summary falls back to `by_format.audio` and `by_format.ebook`.
- `RemoteSession.login_window_seconds` and `created_at`: the sign-in window for the time bar (`login_window_seconds`, else `expires_at - created_at`). Without either, only the countdown is shown.
