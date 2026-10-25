# Book Shelf API v1

REST JSON under `/api/v1`. The React client and future share and MCP lanes build against this file. Request specs in `spec/requests/api/v1` are the executable version of it.

## Conventions

- **Ids.** Every `id` is a UUID. Database ids never leave the server.
- **Errors.** Codes only, the client translates them (`client/src/locales/*/common.json`, key `errors.<code>`):
  ```json
  { "errors": [ { "code": "taken", "field": "email" } ] }
  ```
  `field` is present when the error belongs to an input. Some errors carry extra keys (see `duplicate`).
- **Dates.** ISO 8601 in UTC. Inputs accept `YYYY-MM-DD` or a full timestamp; an empty string clears a date.
- **Status vocabulary** (per edition): `want`, `owned`, `in_progress`, `done`. **Formats:** `audio`, `ebook`, `personal_doc`, `unknown`. The client picks "Reading"/"Listening" and "Read"/"Listened" by format (design README).
- **Shelf keys:** `now`, `want`, `owned`, a year such as `2025`, `no_date`. Order: now, want, owned, years descending, no_date. A book sits on exactly one shelf: `now` if any edition is `in_progress`, else the year of its latest finished edition (`no_date` when finished without a date), else `owned`, else `want`. Design D5 has no shelf for owned books; the client may show `owned` or fold it into another shelf.

## Authentication

Two ways in, both scoped to one user. Another user's id always returns `404 not_found`.

1. **Cookie session** (the SPA, same origin). Every API response sets a readable `CSRF-TOKEN` cookie; send its value as `X-CSRF-Token` on every non-GET request. Missing or wrong token: `403 invalid_csrf`. The session lasts 30 days.
2. **Bearer API token** (iOS Shortcut, Android share target, scripts): `Authorization: Bearer bsh_...`. No CSRF. Tokens cannot reach `/session`, `/api_tokens` or `DELETE /me` (`403 session_required`). An unknown or revoked token: `401 unauthorized`, no fallback to the cookie.

No credentials: `401 unauthorized`. Rate limited endpoints answer `429 rate_limited`.

## Account

| Method | Path | Body | Success | Errors |
| --- | --- | --- | --- | --- |
| POST | `/registration` | `email`, `password` | `201`, empty. Sends a confirmation email linking to `APP_URL/confirm?token=...` | `422` with field codes (`taken`, `invalid`, `too_short`, `blank`), `429` (5/hour/IP) |
| POST | `/confirmation` | `token` | `204` | `422` `confirmation_token: invalid`, `email: already_confirmed`, `email: confirmation_period_expired` |
| POST | `/confirmation/resend` | `email` | `202` always | `429` (5/hour/IP) |
| POST | `/password` | `email` | `202` always. Emails `APP_URL/reset-password?token=...` | `429` (5/hour/IP) |
| PATCH | `/password` | `token`, `password` | `204` | `422` `reset_password_token: invalid` or `expired`, `password: too_short`; `429` |
| POST | `/session` | `email`, `password` | `200 { user }` | `401 invalid_credentials`, `403 unconfirmed`, `429` (10 per 3 min/IP) |
| DELETE | `/session` | | `204` | |
| GET | `/me` | | `200 { user }` | |
| DELETE | `/me` | | `204`. Deletes the account and all its data. The client asks the user to type "удалить" first | `403 session_required` |
| GET | `/api_tokens` | | `200 { api_tokens: [ApiToken] }` (active only) | |
| POST | `/api_tokens` | `name` | `201 { api_token, token }`. `token` is shown only in this response | `400 blank`, `429` (20/hour/IP) |
| DELETE | `/api_tokens/:id` | | `204`, the token stops working at once | `404` |
| GET | `/assistants` | | `200 { assistants: [Assistant] }`: MCP clients (Claude, ChatGPT) with a live grant | `403 session_required` |
| DELETE | `/assistants/:id` | | `204`, revokes every token and grant of that assistant; its next MCP call gets `401` | `404`, `403 session_required` |

```json
// User
{ "id": "uuid", "email": "reader@example.com", "created_at": "2026-10-25T10:00:00.000Z" }
// ApiToken
{ "id": "uuid", "name": "iPhone shortcut", "created_at": "...", "last_used_at": null }
// Assistant: name is the client's host; last_active_at moves at most hourly, on token refresh
{ "id": "uuid", "name": "claude.ai", "client_id": "https://claude.ai/...", "scopes": [ "books:read", "books:write" ],
  "connected_at": "...", "last_active_at": "..." }
```

Every sign up, confirmation, sign in (and failed attempt for a known email), sign out, password reset request and reset, token issue and revoke, assistant connect and revoke, and account deletion is written to the audit log (not exposed over the API).

## Shelf

| Method | Path | Params / body | Success |
| --- | --- | --- | --- |
| GET | `/shelf` | `limit` (books per shelf, default 50, max 200) | `200 { shelves: [ { key, count, books: [BookSummary] } ] }`, empty shelves omitted |
| GET | `/shelf/:key` | `offset`, `limit` | `200 { key, count, books: [BookSummary] }` |
| GET | `/search` | `q` (title, author, original title, ISBN or store id) | `200 { query, answer, books: [BookSummary] }`; `400 blank` for an empty query |
| POST | `/books` | `title`, `author`, `edition: { format, status, started_at, finished_at }` | `201 { book: BookDetail }` |
| GET | `/books/:id` | | `200 { book: BookDetail }` |
| PATCH | `/books/:id` | `title`, `author`, `original_title`, `language`, `year` | `200 { book: BookDetail }`, `422` field codes |
| DELETE | `/books/:id` | | `204` |
| PATCH | `/editions/:id` | `status`, optional `started_at`, `finished_at` | `200 { book: BookSummary }` with the new `shelf` |
| GET | `/books/:id/notes` | | `200 { notes: [Note] }` |
| POST | `/books/:id/notes` | `body` | `201 { note }` |
| PATCH | `/notes/:id` | `body` | `200 { note }` |
| DELETE | `/notes/:id` | | `204` |
| GET | `/books/:id/highlights` | `offset`, `limit` | `200 { highlights: [Highlight], count }` |
| POST | `/books/:id/editions` | `edition: { format, store, status, started_at, finished_at }` | `201 { book: BookDetail }`, `422` field codes |
| POST | `/books/:id/merge` | `other_id` | `200 { book: BookDetail, merge_id }`; `422 { code: "invalid", field: "other_id" }` for the book itself |
| DELETE | `/merges/:id` | | `200 { books: [BookSummary, BookSummary] }` (survivor, restored); `409 already_unmerged` |
| GET | `/duplicates` | | `200 { duplicates: [Duplicate] }`, open ones only |
| DELETE | `/duplicates/:id` | | `204`, dismissed for good |
| GET | `/stats` | `year` (default: current) | `200 Stats` |
| GET | `/sources` | | `200 { sources: [Source] }` |

Any `:id` that is not the caller's: `404 not_found`. Edition fields go in a nested `edition` object because a top-level `format` key is the request format in Rails.

### Add a book

`edition.format` defaults to `unknown`, `edition.status` to `want`. The status is recorded as manual, so imports never overwrite it.

A book with the same title (case and spacing ignored) and the same author (or any author, if none is given) already on the shelf:

```json
// 409
{ "errors": [ { "code": "duplicate", "field": "title" } ], "existing": BookSummary }
```

The client shows "Already on the shelf: Listened · 2024" from `existing`.

### Add a format

`POST /books/:id/editions` adds another format or a copy from another store to a book already on the shelf, with the same defaults and manual status as adding a book. `edition.store` is `litres`, `amazon` or omitted. An existing "want" edition is kept; the shelf already prefers the stronger status.

### Merge, unmerge and possible duplicates

`POST /books/:id/merge` folds `other_id` into `:id`: editions with their statuses, notes and highlights move over, blank fields of `:id` are filled from the other book, and the other book disappears (its id answers `404`). `merge_id` lets the client offer "Undo".

`DELETE /merges/:id` undoes it: the other book comes back with its original id, fields, editions and statuses, and fields the merge filled are cleared unless they were edited since. The pair is then never merged or proposed again automatically.

A background matcher runs after every catalog lookup. It merges on its own only on the same ISBN, or the same original title and author (plan D6); those merges show up in `BookDetail.merges` so they can be undone. A shared title (title or original title, case, punctuation and diacritics ignored) becomes a possible duplicate for the shelf banner: confirm with `POST /books/:id/merge`, reject with `DELETE /duplicates/:id`. There is no transliteration, so a Russian and an English edition match only through `original_title`, and authors in different scripts count as unknown.

```json
// Duplicate
{ "id": "uuid", "reason": "title_author | title", "created_at": "...", "books": [ BookSummary, BookSummary ] }
```

`title_author`: same title and same author. `title`: same title, one author missing or in another script.

### Change status

`PATCH /editions/:id` sets a manual status. A date key that is sent replaces the stored value (empty string clears it); a key that is not sent keeps the stored value. Unknown status: `422 { code: "inclusion", field: "status" }`.

### Search answer

`answer.kind`, plus `book_id` when exactly one book matched:

| kind | Design D11 line |
| --- | --- |
| `listened` | "Listened · Mar 2024" (dates from the audio edition) |
| `read` | "Read · 2023" |
| `read_and_listened` | "Read and listened · 2023, 2024" |
| `in_progress` | "Reading" / "Listening" |
| `owned` | "Owned" |
| `want` | "In Want since May 2025" (`status_updated_at`) |
| `similar` | "Similar: N books" (`count`, titles in `books`) |
| `not_found` | "Not on the shelf" + Want / Read / Listened |

If several books match and exactly one has the query as its whole title, only that book is returned.

### Shapes

```json
// BookSummary
{
  "id": "uuid", "title": "Solaris", "author": "Stanisław Lem", "original_title": null,
  "language": null, "year": null, "page_count": null, "audio_minutes": null, "cover_url": null,
  "cloth": "navy", "shelf": "2024", "bought_twice": false,
  "editions": [ Edition ]
}
// Edition
{
  "id": "uuid", "format": "audio", "store": "litres", "source": "litres", "purchased_at": null,
  "status": "done", "status_source": "manual", "status_updated_at": "...",
  "started_at": null, "finished_at": "2024-03-10T00:00:00.000Z", "total_minutes": null
}
// BookDetail = BookSummary +
{
  "isbn": null, "match_source": "manual", "notes": [ Note ], "highlights": [ Highlight ], "highlights_count": 12,
  "merges": [ { "id": "uuid", "title": "Solaris", "author": "Stanisław Lem", "created_at": "..." } ]
}
// highlights holds the first 5; page the rest with /books/:id/highlights
// Note
{ "id": "uuid", "body": "text", "created_at": "...", "updated_at": "..." }
// Highlight
{ "id": "uuid", "text": "quote", "note": null, "location": "1234", "source": "kindle_browser", "highlighted_at": null }
// Source (one row per kind: litres, kindle_export, kindle_browser)
{ "kind": "litres", "status": "never | ok | error | needs_login", "last_sync_at": null, "error": null }
```

`cloth` is the spine cloth (design README «Корешки»): `oxblood`, `bottle`, `navy`, `plum`, `slate`, `ochre`, `sage` or `linen`, the nearest to the cover's dominant colour in OKLab, or a stable pick by book id while there is no cover. Never null. `language` (ISO 639-1, sets the spine text direction), `page_count` and `audio_minutes` (spine width) are null until a source or the catalog knows them.

`bought_twice` is true when the book has editions from both stores ("You bought this book twice"). `merges` lists merges into this book that can still be undone with `DELETE /merges/:id`.

`store`: `litres`, `amazon` or null. `source`: `manual`, `share`, `mcp`, `litres`, `kindle_export`, `kindle_browser`. `status_source`: `manual`, `litres`, `kindle_browser`, `kindle_export`, `purchase`. `Source.error` is a code.

### Stats

Only finished editions with a `finished_at` count, by the latest finish in the year. A book counts once; formats are a breakdown, so `by_format` can add up to more than `total`.

```json
{
  "year": 2025,
  "years": [ 2025, 2024 ],
  "total": 18,
  "by_format": { "audio": 11, "ebook": 7 },
  "total_minutes": null,
  "months": [ { "month": 1, "books": [ { "id": "uuid", "title": "...", "author": "...", "formats": [ "audio" ], "finished_at": "...", "minutes": null } ] } ],
  "no_date_count": 3,
  "top_authors": [ { "author": "Lem", "count": 3 } ]
}
```

`months` always has 12 entries. `years` lists every year with a finished book, for the year picker. `no_date_count` covers all years. `total_minutes` and `minutes` are null when no duration is known.

### Catalog enrichment

Every new book is looked up in Open Library, then Google Books, in a background job, never during the request. The lookup fills only blank fields (`cover_url`, `year`, `language`, `page_count`, `original_title`, `isbn`), so manual values and covers from a store sync win. It sets `match_source` to `catalog`. A book that was just added has no catalog data yet; poll `GET /books/:id` or refetch the shelf later. Rate limited lookups back off and retry; a daily job retries books whose lookup never finished. `GOOGLE_BOOKS_API_KEY` raises the Google quota.

## Error codes

`unauthorized`, `session_required`, `invalid_csrf`, `not_found`, `rate_limited`, `blank`, `invalid_credentials`, `unconfirmed`, `taken`, `invalid`, `too_short`, `too_long`, `inclusion`, `already_confirmed`, `confirmation_period_expired`, `expired`, `duplicate`, `already_unmerged`, `not_implemented`.

## MCP (AI assistants)

Outside `/api/v1`. A remote MCP server over Streamable HTTP for Claude and ChatGPT connectors, OAuth 2.1 with PKCE. `MCP_AUTH.md` explains why it is built this way.

| Method | Path | Purpose |
| --- | --- | --- |
| POST | `/mcp` | MCP JSON-RPC, stateless, JSON responses. `Authorization: Bearer <OAuth access token>` only; API tokens (`bsh_...`) are not accepted |
| GET | `/.well-known/oauth-protected-resource`, `/.well-known/oauth-protected-resource/mcp` | RFC 9728 metadata: `resource` = `APP_URL/mcp`, `authorization_servers` = [`APP_URL`] |
| GET | `/.well-known/oauth-authorization-server` | RFC 8414 metadata (CIMD, PKCE S256, `none` client auth) |
| GET, POST, DELETE | `/oauth/authorize` | Consent page (server-rendered, ru or en by `Accept-Language`), allow, deny |
| POST | `/oauth/token` | Code and refresh token exchange; refresh tokens rotate; access tokens live 1 hour |
| POST | `/oauth/revoke` | RFC 7009 |

Without a valid token `/mcp` answers `401` with `WWW-Authenticate: Bearer scope="books:read books:write", resource_metadata=".../.well-known/oauth-protected-resource/mcp"`, plus `error="invalid_token"` for an unknown, expired, revoked or foreign-audience token. Scopes: `books:read` (search_shelf, get_book, reading_stats), `books:write` (add_book). Only clients whose `client_id` is a metadata document URL on `claude.ai` or `chatgpt.com` can connect.

Tools return `structuredContent` with codes and data (the REST shapes: search answer kinds, BookSummary, BookDetail) and a one-line English text summary. Errors set `isError` with `{ "error": { "code", "field" } }`, codes from the list below; another user's book id is `not_found`.

| Tool | Arguments | structuredContent |
| --- | --- | --- |
| `search_shelf` | `query` | same as `GET /search` |
| `get_book` | `book_id` | `{ book: BookDetail }` |
| `add_book` | `title`, `author`, `status` (default `want`), `format` (default `unknown`), `finished_at` (`YYYY-MM-DD`) | `{ code: "added" or "duplicate", book: BookSummary }`; the edition `source` is `mcp` |
| `reading_stats` | `year` (default current), `author` (substring) | `{ year, author, total, listened, read, top_authors, years, books }` |

### SPA contract (client lane)

- **Login with `return_to`.** A signed-out user who opens `/oauth/authorize` is sent to `APP_URL/login?return_to=<path>`. After `POST /session` succeeds, the SPA does a full page load (`window.location.assign`) to `return_to` when it starts with `/oauth/authorize`, and ignores it otherwise. Sign up and email confirmation keep `return_to` through to the login.
- **Profile > Assistants.** List from `GET /assistants` (name, connected date) with a revoke button calling `DELETE /assistants/:id`. The empty state can explain how to connect: in Claude, Customize > Connectors > Add custom connector, URL `APP_URL/mcp`.
- The consent page is server-rendered; the SPA does not render it.

## Health

`GET /up` returns 200 when the app boots (outside `/api/v1`).
