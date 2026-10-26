# Book Shelf

Personal bookshelf for Litres audiobooks and Kindle books. Rails 8.1 API + React (Vite) PWA, one Postgres database, background jobs run inside Puma (Solid Queue).

## Requirements

- Ruby 3.4.8 (`.ruby-version`)
- Postgres 14+
- Node 22

## Setup

```sh
bin/setup              # gems, client packages, database
bin/dev                # Rails API + jobs on :3000
cd client && npm run dev   # Vite on :5173, proxies /api to :3000
```

Open http://localhost:5173. Emails (confirmation, password reset) open in the browser via letter_opener.

## Tests

```sh
bundle exec rspec
cd client && npm test -- --run && npm run lint
```

## Production

`Dockerfile` builds the client into `public/` and serves it from Rails on one origin. `railway.toml` deploys it on Railway.

Environment: `DATABASE_URL`, `SECRET_KEY_BASE`, `APP_URL` (public URL, used in email links), `MAIL_FROM`, `RESEND_API_KEY` (mail goes through the Resend HTTP API, Railway blocks outbound SMTP). Set `SOLID_QUEUE_IN_PUMA=false` only if jobs move to a separate worker.

API contract: [API.md](API.md).
