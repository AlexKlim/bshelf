# Calls and fields ahead of API.md

The optional fields in `lib/types.ts` below are not in API.md yet. Each one degrades quietly when the server does not have it.

## Optional fields

- `StatsBook.cloth`: without it the year shelf draws the book in `spine-blank`.
- `Stats.listened` and `Stats.read`: without them the summary falls back to `by_format.audio` and `by_format.ebook`.
- `RemoteSession.login_window_seconds` and `created_at`: the sign-in window for the time bar (`login_window_seconds`, else `expires_at - created_at`). Without either, only the countdown is shown.
