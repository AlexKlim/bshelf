# Book Shelf API v1

REST JSON under `/api/v1`. The React client, the share targets and scripts build against this file. Request specs in `spec/requests/api/v1` are the executable version of it.

## Conventions

- **Ids.** Every `id` is a UUID. Database ids never leave the server.
- **Errors.** Codes only, the client translates them (`client/src/locales/*/common.json`, key `errors.<code>`):
  ```json
  { "errors": [ { "code": "taken", "field": "email" } ] }
  ```
  `field` is present when the error belongs to an input. Some errors carry extra keys (see `duplicate`).
- **Dates.** ISO 8601 in UTC. Inputs are strings, `YYYY-MM-DD` or a full ISO 8601 timestamp from 1900 to tomorrow (server date plus one day, for readers ahead of UTC), since a reading cannot start or finish in the future; an empty string or `null` clears a date. Anything else, a number, boolean or array included, answers `422 { code: "invalid", field }` (`started_at`, `finished_at`).
- **Status vocabulary** (per edition): `want`, `owned`, `in_progress`, `done`. **Formats:** `audio`, `ebook`, `personal_doc`, `unknown`. The client picks "Reading"/"Listening" and "Read"/"Listened" by format (design README).
- **Shelf keys:** `now`, `want`, `owned`, a year such as `2025`, `no_date`. Order: now, want, owned, years descending, no_date. A book sits on exactly one shelf: `now` if any edition is `in_progress`, else the year of its latest finished edition (`no_date` when finished without a date), else `owned`, else `want`. The design has no shelf for owned books; the client may show `owned` or fold it into another shelf.

## Authentication

Two ways in, both scoped to one user. Another user's id always returns `404 not_found`.

1. **Cookie session** (the SPA, same origin). Every API response sets a readable `CSRF-TOKEN` cookie; send its value as `X-CSRF-Token` on every non-GET request. Missing or wrong token: `403 invalid_csrf`. The session lasts 30 days.
2. **Bearer API token** (iOS Shortcut, Android share target, scripts): `Authorization: Bearer bsh_...`. No CSRF. A token may call `GET` endpoints and `POST /share`, `POST /share/add`; every other write (books, editions, notes, merges, duplicates, remote browser) and `/api_tokens`, `/assistants`, `PATCH /me/password`, `DELETE /me`, `DELETE /session` answer `403 session_required`. An unknown or revoked token: `401 unauthorized`, no fallback to the cookie.

No credentials: `401 unauthorized`. Rate limited endpoints answer `429 rate_limited`.

## Account

| Method | Path | Body | Success | Errors |
| --- | --- | --- | --- | --- |
| POST | `/registration` | `email`, `password` | `201`, empty. Sends a confirmation email linking to `APP_URL/confirm?token=...` | `422` with field codes (`taken`, `invalid`, `too_short`, `blank`), `429` (5/hour/IP) |
| POST | `/confirmation` | `token` | `204` | `422` `confirmation_token: invalid`, `email: already_confirmed`, `email: confirmation_period_expired` |
| POST | `/confirmation/resend` | `email` | `202` always | `429` (5/hour/IP) |
| POST | `/password` | `email` | `202` always. Emails `APP_URL/reset-password?token=...` | `429` (5/hour/IP) |
| PATCH | `/password` | `token`, `password` | `204`. Revokes every API token and connected assistant of the account | `422` `reset_password_token: invalid` or `expired`, `password: too_short`; `429` (5/hour/IP, counted apart from `POST /password`) |
| POST | `/session` | `email`, `password` | `200 { user }` | `401 invalid_credentials`, `403 unconfirmed`, `429` (10 attempts per 3 min per IP; after 10 failed attempts per 3 min for an email, that email answers `429` even with the right password) |
| DELETE | `/session` | | `204` | |
| GET | `/me` | | `200 { user }` | |
| PATCH | `/me/password` | `current_password`, `password` | `204`. This session stays signed in; other sessions, every API token and connected assistant are signed out | `422` `current_password: invalid` or `blank`, `password: too_short`; `403 session_required`; `429` (10/hour/account) |
| DELETE | `/me` | | `204`. Ends a running remote browser session, then deletes the account and all its data. The client asks the user to type "удалить" first | `403 session_required` |
| GET | `/api_tokens` | | `200 { api_tokens: [ApiToken] }` (active only) | |
| POST | `/api_tokens` | `name` | `201 { api_token, token }`. `token` is shown only in this response | `400 blank`, `429` (20/hour/IP) |
| DELETE | `/api_tokens/:id` | | `204`, the token stops working at once | `404` |
| GET | `/assistants` | | `200 { assistants: [Assistant], gemini_client: { client_id, created_at } or null }`: MCP clients (Claude, ChatGPT, Gemini) with a live grant, and the account's Gemini key without its secret | `403 session_required` |
| DELETE | `/assistants/:id` | | `204`, revokes every token and grant of that assistant; its next MCP call gets `401` | `404`, `403 session_required` |
| POST | `/assistants/gemini_client` | | `201 { client_id, client_secret }`. Creates the account's Gemini key, replacing the old one and deleting its tokens. `client_secret` is shown only in this response and stored hashed | `403 session_required`, `429` (10/hour/IP) |
| DELETE | `/assistants/gemini_client` | | `204`, deletes the key and every token issued to it | `404`, `403 session_required` |

```json
// User
{ "id": "uuid", "email": "reader@example.com", "created_at": "2026-10-25T10:00:00.000Z" }
// ApiToken
{ "id": "uuid", "name": "iPhone shortcut", "created_at": "...", "last_used_at": null }
// Assistant: name is the client's host; connected_at is the first grant or token ever issued to it,
// last_active_at the latest token (it moves at most hourly, on token refresh)
{ "id": "uuid", "name": "claude.ai", "client_id": "https://claude.ai/...", "scopes": [ "books:read", "books:write" ],
  "connected_at": "...", "last_active_at": "..." }
```

Every sign up, confirmation, sign in (and failed attempt for a known email), sign out, password reset request, reset and change, token issue and revoke, assistant connect and revoke, Gemini key issue and revoke, and account deletion is written to the audit log (not exposed over the API). Deleting the account clears the IP addresses of its audit rows; the deletion row keeps only the account uuid.

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
| GET | `/sources` | | `200 { sources: [Source], banner: Banner \| null }` (see Sources) |
| POST | `/sources/kindle_export/request`, `/sources/kindle_export/upload` | | Not implemented yet: always `501 not_implemented`, so the client can show "not available yet" |

Any `:id` that is not the caller's: `404 not_found`. Edition fields go in a nested `edition` object because a top-level `format` key is the request format in Rails.

### Add a book

`edition.format` defaults to `unknown`, `edition.status` to `want`. The status is recorded as manual, so imports never overwrite it.

A book with the same title (case, punctuation and diacritics ignored, the matcher's rule) and the same author (one name contained in the other, e.g. "Herbert" and "Frank Herbert"; any author if none is given) already on the shelf:

```json
// 409
{ "errors": [ { "code": "duplicate", "field": "title" } ], "existing": BookSummary }
```

The client shows "Already on the shelf: Listened · 2024" from `existing`.

### Add a format

`POST /books/:id/editions` adds another format or a copy from another store to a book already on the shelf, with the same defaults and manual status as adding a book. `edition.store` is `litres`, `amazon` or omitted. An existing "want" edition is kept; the shelf already prefers the stronger status.

### Merge, unmerge and possible duplicates

`POST /books/:id/merge` folds `other_id` into `:id`: editions with their statuses, notes and highlights move over, blank fields of `:id` are filled from the other book, its possible duplicates (dismissed ones too) now pair with `:id`, and the other book disappears (its id answers `404`). `merge_id` lets the client offer "Undo".

`DELETE /merges/:id` undoes it: the other book comes back with its original id, fields, editions and statuses, and fields the merge filled are cleared unless they were edited since. Its possible duplicates return to it. The pair is then never merged or proposed again automatically.

A background matcher runs after every catalog lookup. It merges on its own only on the same original title and author; those merges show up in `BookDetail.merges` so they can be undone. A shared ISBN only proposes a duplicate: every stored ISBN was filled in by the catalog, which found it by title. A shared title (title or original title, case, punctuation and diacritics ignored) becomes a possible duplicate for the shelf banner: confirm with `POST /books/:id/merge`, reject with `DELETE /duplicates/:id`. There is no transliteration, so a Russian and an English edition match only through `original_title`, and authors in different scripts count as unknown.

```json
// Duplicate
{ "id": "uuid", "reason": "title_author | title", "created_at": "...", "books": [ BookSummary, BookSummary ] }
```

`title_author`: same title and same author. `title`: same title, one author missing or in another script.

### Change status

`PATCH /editions/:id` sets a manual status. A date key that is sent replaces the stored value (empty string clears it); a key that is not sent keeps the stored value. Moving an edition to `done` without sending `finished_at` sets it to now when none is stored, so a book marked Read lands on this year's shelf; moving to `in_progress` does the same for `started_at`. Adding a finished book without a date (`POST /books`, `/share/add`, MCP) keeps it on `no_date`. Unknown status: `422 { code: "inclusion", field: "status" }`.

### Search answer

`answer.kind`, plus `book_id` when exactly one book matched:

| kind | Line |
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
{
  "kind": "kindle_browser", "status": "never | ok | error | needs_login", "last_sync_at": null, "error": null,
  "books_count": 148,
  "session": { "id": "uuid", "status": "collecting", "result": null, "interruption": null }
}
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
  "listened": 11,
  "read": 9,
  "by_format": { "audio": 11, "ebook": 7 },
  "total_minutes": null,
  "months": [ { "month": 1, "books": [ { "id": "uuid", "title": "...", "author": "...", "cloth": "navy", "formats": [ "audio" ], "finished_at": "...", "minutes": null } ] } ],
  "no_date_count": 3,
  "top_authors": [ { "author": "Lem", "count": 3 } ]
}
```

`listened` counts books with a finished audio edition, `read` books with any other finished format (the MCP `reading_stats` tool counts the same way), so a book can count in both. `cloth` follows the BookSummary rule. `months` always has 12 entries. `years` lists every year with a finished book, for the year picker. `no_date_count` covers all years. `total_minutes` and `minutes` are null when no duration is known.

### Catalog enrichment

Every new book is looked up in Open Library, then Google Books, in a background job, never during the request. The lookup fills only blank fields (`cover_url`, `year`, `language`, `page_count`, `original_title`, `isbn`), so manual values and covers from a store sync win. An ISBN is taken only from an ISBN lookup or a catalog entry with the same full title, so a series volume never borrows another volume's ISBN. It sets `match_source` to `catalog`. A book that was just added has no catalog data yet; poll `GET /books/:id` or refetch the shelf later. Rate limited lookups back off and retry; a daily job retries books whose lookup never finished. Cached catalog answers expire after 30 days and a daily job deletes them. `GOOGLE_BOOKS_API_KEY` raises the Google quota.

## MCP (AI assistants)

Outside `/api/v1`. A remote MCP server over Streamable HTTP for Claude, ChatGPT and Gemini Enterprise connectors, OAuth 2.1 with PKCE. `MCP_AUTH.md` explains why it is built this way.

| Method | Path | Purpose |
| --- | --- | --- |
| POST | `/mcp` | MCP JSON-RPC, stateless, JSON responses. `Authorization: Bearer <OAuth access token>` only; API tokens (`bsh_...`) are not accepted |
| GET | `/.well-known/oauth-protected-resource`, `/.well-known/oauth-protected-resource/mcp` | RFC 9728 metadata: `resource` = `APP_URL/mcp`, `authorization_servers` = [`APP_URL`] |
| GET | `/.well-known/oauth-authorization-server` | RFC 8414 metadata (CIMD, PKCE S256, `none`, `client_secret_basic` and `client_secret_post` client auth) |
| GET, POST, DELETE | `/oauth/authorize` | Consent page (server-rendered in en or ru, chosen like share answers: `locale`, then the first supported `Accept-Language` language, else en), allow, deny. `GET` answers `429` after 20 requests per minute per IP |
| POST | `/oauth/token` | Code and refresh token exchange; refresh tokens rotate; access tokens live 1 hour |
| POST | `/oauth/revoke` | RFC 7009 |

Without a valid token `/mcp` answers `401` with `WWW-Authenticate: Bearer scope="books:read books:write", resource_metadata=".../.well-known/oauth-protected-resource/mcp"`, plus `error="invalid_token"` for an unknown, expired, revoked or foreign-audience token. Scopes: `books:read` (search_shelf, get_book, reading_stats), `books:write` (add_book). Clients that can connect: a metadata document URL on `claude.ai` or `chatgpt.com` as `client_id` (public, PKCE required, no secret), or the account's own Gemini key from `POST /assistants/gemini_client` (confidential: secret by Basic or in the body, PKCE checked when sent, redirect only `https://vertexaisearch.cloud.google.com/oauth-redirect`, authorized only by its owner, tokens bound to `APP_URL/mcp` even without `resource`).

Tools return `structuredContent` with codes and data (the REST shapes: search answer kinds, BookSummary, BookDetail) and a one-line English text summary. Errors set `isError` with `{ "error": { "code", "field" } }`, codes from the list below; another user's book id is `not_found`.

| Tool | Arguments | structuredContent |
| --- | --- | --- |
| `search_shelf` | `query` | same as `GET /search` |
| `get_book` | `book_id` | `{ book: BookDetail }` |
| `add_book` | `title`, `author`, `status` (default `want`), `format` (default `unknown`), `finished_at` (`YYYY-MM-DD`) | `{ code: "added" or "duplicate", book: BookSummary }`; the edition `source` is `mcp` |
| `reading_stats` | `year` (default current), `author` (substring) | `{ year, author, total, listened, read, top_authors, years, books }` |

### SPA contract

- **Login with `return_to`.** A signed-out user who opens `/oauth/authorize` is sent to `APP_URL/login?return_to=<path>`. After `POST /session` succeeds, the SPA does a full page load (`window.location.assign`) to `return_to` when it starts with `/oauth/authorize`, and ignores it otherwise. Sign up and email confirmation keep `return_to` through to the login.
- **Account > Assistants (MCP)** (`/account/assistants`). Connection URL `APP_URL/mcp` with Copy, steps for Claude, ChatGPT or Gemini; the Gemini steps create the key (`POST /assistants/gemini_client`) and show its secret once with the authorization and token URLs. List from `GET /assistants` (name, connected date) with a revoke button calling `DELETE /assistants/:id`.
- The consent page is server-rendered; the SPA does not render it.

## Share (check before buying)

| Method | Path | Body | Success |
| --- | --- | --- | --- |
| POST | `/share` | `url`, `text`, `title` (any of them), optional `locale` | `200 ShareAnswer`; `400 blank` when all are empty; `429` (30/min/IP) |
| POST | `/share/add` | `title`, `author`, `edition: { format, status, store, external_id, finished_at }`, optional `locale` | `201 { book: BookSummary, message }`; `409 duplicate` with `existing`; `422` field codes; `429` |

Both work with the Bearer token (iOS Shortcut) and the cookie session (Android share target page).

How a share is matched, in order:
1. The first `http(s)` URL in `url` or `text`. Litres: the id at the end of the path (`.../solyaris-6450429/`). Amazon: the ASIN after `/dp/`, `/gp/product/`, `/gp/aw/d/`. Short links (`a.co`, `amzn.to`, `amzn.eu`, ...) are followed by redirect, the page itself is never read. The id is looked up in the caller's editions (`store` + `external_id`). Imports must store the Litres art id and the ASIN there.
2. Otherwise the text: it is split on ` - `, ` | `, `: `, ` by `, `, ` and newlines; store names and words such as "eBook" are dropped. A segment equal to a title or original title (or an ISBN) wins, then a segment contained in a title. Authors alone never match, so "Lem - Solaris" does not answer with another Lem book.
3. A link that fails to resolve falls back to the text (`link: null`).

Link safety: only Litres and Amazon hosts on ports 80/443, every DNS answer must be public (private, loopback, link-local, CGNAT, multicast and IPv4-mapped forms are refused) and the connection goes to the checked IP. At most 3 redirects and 1.5 s for the whole resolution; only the status line and headers are read, never a body.

```json
// ShareAnswer
{
  "query": "Solaris",
  "answer": { "kind": "listened", "book_id": "uuid" },
  "books": [ BookSummary ],
  "message": "Listened · Mar 2024",
  "link": { "store": "amazon", "external_id": "0156027607" },
  "suggestion": null
}
```

`answer.kind` is the search vocabulary (`listened`, `read`, `read_and_listened`, `in_progress`, `owned`, `want`, `similar`, `not_found`) plus `unrecognized` (no usable link and no text). `message` is the ready line in `en` or `ru` (from `locale`, else the first supported language in `Accept-Language`, else `en`), for clients that cannot render `answer`:

| kind | en | ru |
| --- | --- | --- |
| listened | Listened · Mar 2024 | Слушали · март 2024 |
| read | Read · 2023 | Читали · 2023 |
| read_and_listened | Read and listened · 2023, 2024 | Читали и слушали · 2023, 2024 |
| in_progress | Listening / Reading | Слушаю / Читаю |
| owned | Owned | На полке |
| want | In Want since May 2025 | В Хочу с мая 2025 |
| similar | Similar: 2 books | Похожие: 2 книги |
| not_found | Not on the shelf | Не на полке |
| unrecognized | Could not recognize the book | Не удалось распознать книгу |

The date part is left out when the edition has no finish date. For `not_found` and `unrecognized`, `suggestion` is `{ title, author, store, external_id }`: the first two text segments and the resolved link, any of them may be null. Post it to `/share/add` as is: Want / Read / Listened is the first tap (`status` `want` or `done`; Read means `format: ebook`, Listened `format: audio`), the format is the second tap only for Want. `title` is required, so a link-only share without text needs one typed title.

### iOS Shortcut

Installed from "Account" -> "Share shortcut" -> "Install the shortcut" (an iCloud link; the client creates an API token and copies it to the clipboard). The shortcut, built by hand:

1. Receives URLs and text from the share sheet. On first run it asks for the token and saves it to a file in Shortcuts.
2. `Get contents of URL`: `POST https://<host>/api/v1/share`, headers `Authorization: Bearer bsh_...`, `Content-Type: application/json`, JSON body `{ "url": <Shortcut Input as URL>, "text": <Name of Shortcut Input> }`.
3. `Show notification` with `message`.
4. If `answer.kind` is `not_found`: `Choose from menu` Want / Read / Listened; for Want a second menu Audio / Ebook. Then `POST /api/v1/share/add` with `title`, `author` from `suggestion`, `edition: { status, format, store, external_id }` and show `message`. If `suggestion.title` is null, `Ask for input` first.
5. If `answer.kind` is `similar`: `Show result` with `books[].title`, one per line.

### Android

The PWA manifest declares `share_target` -> `GET /share?title=&text=&url=`. That client route posts the three fields to `/share` with the cookie session and renders the same answer and quick add.

## Remote browser (Sync Kindle, Litres captcha)

Cookie session only (`403 session_required` for API tokens). Screen flow: `design/components/RemoteBrowser/README.md`.

| Method | Path | Body | Success | Errors |
| --- | --- | --- | --- | --- |
| POST | `/remote_browser_sessions` | `purpose` (`kindle`, `litres`), `disclosure_accepted: true` | `201 { session }`; `200 { session }` with the person's running session if there is one | `422 inclusion` (purpose), `422 accepted` (disclosure_accepted), `503 unavailable` (instance flag off or no collector for the purpose), `429` (10/hour/IP) |
| GET | `/remote_browser_sessions/:id` | | `200 { session }` | `404` |
| DELETE | `/remote_browser_sessions/:id` | | `200 { session }`, interrupted with `aborted` (no-op once ended) | `404` |
| POST | `/remote_browser_sessions/:id/viewer` | | `200 { url, expires_at }` | `409 not_live`, `404` |
| GET | `/remote_browser_sessions/:id/view/*path` | `token` on the first request | the live view, proxied from Steel | `403 invalid_token`, `404` |

```json
// RemoteBrowserSession
{
  "id": "uuid", "purpose": "kindle",
  "status": "queued | connecting | live | collecting | done | interrupted",
  "queue_position": 1,            // only while queued
  "expires_at": "...",            // end of the 5:00 sign-in, set when live
  "seconds_left": 287,            // only while live
  "login_window_seconds": 300,    // length of the whole sign-in window, for the timer's full scale
  "steps": [ { "key": "library", "state": "done" }, { "key": "highlights", "state": "pending" } ],
  "result": { "books": 12, "highlights": 40 },  // when done
  "interruption": null,           // aborted | timeout | provider_refused | deploy_interrupted | browser_failed
  "created_at": "...", "finished_at": null
}
```

Flow: show the disclosure, `POST` with `disclosure_accepted: true`, then poll `GET` every 1-2 s. `queued` -> "Browser busy, you are next" with `queue_position`. `connecting` -> skeleton. `live` -> `POST .../viewer` and load `url` in a full-screen iframe, timer from `seconds_left`. `collecting` -> `steps`; the person may leave; the Kindle row of `/sources` carries the session (and later its result) when they come back. `done` -> "+N books, M highlights". `interrupted` texts: `aborted` (nothing), `timeout` "Time is up", `provider_refused` "Amazon did not let you in", `deploy_interrupted` and `browser_failed` "Session interrupted, sign in again".

Reconnect: when the page becomes visible again, `GET` the session; if it is still `live`, `POST .../viewer` again and reload the iframe. The timer keeps running, the browser is the same.

Live view security: Steel sits on the private network only (`STEEL_URL`, must be `*.internal`, `localhost` or a private IP, checked at boot). `viewer` returns a token that works once, for 1 minute, only for its session and only for the session's owner. The first request trades it for an httponly, `SameSite=Strict` cookie scoped to `/api/v1/remote_browser_sessions/:id/view`, which covers the page's subresources until the sign-in time ends or the session leaves `live`. Only the viewer path Steel issued for the session is proxied, with the query Steel gave it; the query the client sends is never forwarded. Responses carry `Cache-Control: no-store` and `frame-ancestors 'self'`. The viewer streams over a websocket at `view/v1/sessions/cast`: the page's websocket address is rewritten to this proxy, and after the same cookie check the upgrade is piped byte for byte to Steel until the sign-in time ends. Only `pageId`, `pageIndex` and `tabInfo` pass in its query.

Limits: `REMOTE_BROWSER_MAX_SESSIONS` browsers at once (default 1), the rest wait in a FIFO queue. One running session per person. `REMOTE_BROWSER_DISABLED=1` is the instance kill switch. A deploy interrupts sessions that are `collecting` (`deploy_interrupted`); `live` sessions carry on in the new process. Every start and finish goes to the audit log; `done`, store refusals (`provider_refused`) and changed store pages (`page_changed`, shown to the person as `browser_failed`) update the `kindle_browser` (or `litres`) source; a failure of our own browser does not. A job sweeps stale sessions every minute: `live` past its sign-in window becomes `timeout`, `connecting` or `collecting` without progress for 15 minutes becomes `deploy_interrupted`.

## Error codes

`unauthorized`, `session_required`, `invalid_csrf`, `not_found`, `rate_limited`, `blank`, `invalid_credentials`, `unconfirmed`, `taken`, `invalid`, `too_short`, `too_long`, `inclusion`, `already_confirmed`, `confirmation_period_expired`, `expired`, `duplicate`, `already_unmerged`, `not_implemented`, `accepted`, `unavailable`, `not_live`, `invalid_token`.

## Sources

`Source.session` is the latest remote browser session for that source (`kindle` -> `kindle_browser`, `litres` -> `litres`) while it runs and for a day after it ends, else null. It lets the row show "+12 books, 40 highlights" and reconnect after the app was closed. `books_count` counts editions imported from that source. Error codes so far: `needs_login`, `invalid_credentials`, `captcha_required`, `provider_refused`, `page_changed`, `timeout` (adapters add theirs). The first three set `status` to `needs_login`: the person has to sign in to the store again; any other error sets `error`.

`banner` fills the single slot above the shelf, highest priority first:

| kind | when | extra keys |
| --- | --- | --- |
| `source_error` | any source in `error` or `needs_login` | `source`, `error` (code, or `needs_login`) |
| `export_ready` | not emitted yet: needs the Amazon export import | |
| `litres_reminder` | the last Litres sync is older than 30 days | |
| `possible_duplicates` | undismissed `GET /duplicates` rows exist; `key` follows the newest pair | `count` |

Every banner has `dismissible` (false for `source_error`) and `key`, which changes with each new event: the client stores dismissed keys, so a dismissed banner returns only for the next event.

## Operations

Adapters report through `SourceConnection.record_sync!(user, kind, error:, status:)`: it updates the Sources row and writes a `metric_events` row (`sync.<kind>`, outcome `ok` or the error code). Share writes `share` with its answer kind and duration, the remote browser `remote_browser` with its outcome. Each of these is also one JSON log line (`event`, `outcome`, `user_id`, `duration_ms`).

`HealthCheckJob` runs hourly (`config/recurring.yml`), logs a `metrics.summary` line and one `{"event":"alert"}` error line per alert, and deletes metric rows older than 30 days. Alerts, over the last 24 h unless noted:

| alert | condition |
| --- | --- |
| `sync_failure_rate` | more than 50% of at least 4 syncs of one source failed |
| `sync_error` | any `page_changed` or `provider_refused` |
| `share_slow` | share p95 over 2 s |
| `job_failures` | failed Solid Queue jobs in the last hour |

Point the platform's log alerting at `"event":"alert"`. Ad hoc dashboard: `bin/rails runner 'pp HealthCheck.call'`. The status journal is `status_changes`.

## Health

`GET /up` returns 200 when the app boots (outside `/api/v1`).
