# Assumed API, not in API.md yet

Everything else the client calls is in API.md (phase 1, catalog, MCP and share/remote browser/sources lanes, merged into `feat/v1` at 48ce178). The calls below live in `pending.ts` or as optional fields in `lib/types.ts`. Each one fails soft today (404 or missing field) and the screen shows an error or hides the extra line.

## Litres sign in and sync (Sources > Litres, EmptyCase path 1)

- `POST /api/v1/sources/litres/sync` `{ login, password }` -> `200 { books, highlights }` (same shape as `RemoteBrowserSession.result`).
- Errors: `422` with `field: "password"` or `"login"` and a code; codes are translated through `sourceErrors.<code>` (`invalid_credentials`, `timeout`, `blocked`), else `errors.<code>`.
- `422 captcha_required`: the client opens `/sources/litres/captcha`, the remote browser flow with `purpose: "litres"` (in API.md).
- The password is sent once and never stored by the client; the field is cleared after every attempt.

## Amazon export (Sources > Amazon export, EmptyCase path 2)

- `POST /api/v1/sources/kindle_export/request` -> `204`. Marks that the person asked Amazon for the archive.
- `POST /api/v1/sources/kindle_export/upload` multipart `archive` (zip) -> `200 { books, highlights }`; `422 invalid_archive`.
- `Source` for `kindle_export` with `status: "requested"` and `requested_at` drives the waiting state ("Requested on 25 October. Amazon is preparing the archive, usually 1-3 days.") and the disabled "Waiting for archive" button. `status: "ready"` shows "Upload archive". API.md lists only `never | ok | error | needs_login`.
- `banner.kind: "export_ready"` with optional `count` is already rendered (API.md says it is not emitted yet).

## Stats

- `StatsBook.cloth` (optional). Without it the client picks the cloth with the server's own fallback (`Zlib.crc32(uuid) % 8`, `lib/cloth.ts`), so a book without a cover has the same cloth on the year shelf as on the bookcase; a book whose cloth came from its cover may differ until `cloth` is added to the stats rows.

## Notes for reconciling

- `ShareAnswer.message` and `/share/add` `message` use "Прослушал · март 2024", while design D11 and the client say "Слушали · март 2024" for the search answer. The share page renders its own D11 line for known kinds and shows the server `message` only after an add.
- `GET /shelf` is read with `limit=200`; a shelf with more books shows the right count on its plaque but only the first 200 spines (no paging through `/shelf/:key` yet).
