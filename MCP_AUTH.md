# MCP authorization: how assistants connect

Checked 2026-10-25 against primary sources. Question: how do Claude (web, desktop, mobile) and ChatGPT register as OAuth clients of a remote MCP server today, what must the server expose, and does Doorkeeper cover it.

## MCP authorization spec

Current protocol version is `2026-07-28` ([versioning](https://modelcontextprotocol.io/specification/versioning)).

- The MCP server is an OAuth 2.1 resource server and MUST serve RFC 9728 protected resource metadata. Clients find the authorization server only through it ([authorization](https://modelcontextprotocol.io/specification/draft/basic/authorization)).
- The authorization server MUST offer RFC 8414 metadata or OIDC discovery and MUST support PKCE; `code_challenge_methods_supported` must list `S256`.
- Clients MUST send the RFC 8707 `resource` parameter (the canonical MCP URL, e.g. `https://host/mcp`) in both the authorization and the token request. The MCP server MUST check that the token was issued for it (audience) and answer 401 for invalid or expired tokens, 403 `insufficient_scope` for missing scopes.
- 401 carries `WWW-Authenticate: Bearer resource_metadata="..."`, optionally `scope="..."`.
- RFC 9207: the authorization server SHOULD return `iss` in authorization responses and advertise `authorization_response_iss_parameter_supported`.
- Client registration ([client-registration](https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization/client-registration)): Client ID Metadata Documents (CIMD) are SHOULD; pre-registration is supported; **Dynamic Client Registration (DCR) is deprecated**, kept for backwards compatibility. For CIMD the AS MUST check that the fetched document's `client_id` equals the URL and MUST check `redirect_uri` against its `redirect_uris`; a domain trust policy (allowlist) is explicitly allowed.

## Claude (claude.ai web, Desktop, iOS, Android, Cowork)

Source: [Authentication for connectors](https://claude.com/docs/connectors/building/authentication.md), [Add a custom connector](https://claude.com/docs/connectors/custom/add-unlisted.md), [Lazy authentication](https://claude.com/docs/connectors/building/lazy-authentication.md).

- One OAuth stack backs claude.ai, Desktop, mobile, Claude Code and Cowork. A custom connector is added under Customize > Connectors (Free: one connector; Pro/Max: own account) and is then usable from the mobile app, which signs in through the same flow.
- Registration: supports **CIMD**, **DCR** and a **user-entered client id** ("Use your own OAuth client"). The dialog's recommended default is "Use Claude's published identity" (CIMD). Claude uses CIMD only when AS metadata has `client_id_metadata_document_supported: true` **and** `"none"` in `token_endpoint_auth_methods_supported`; otherwise it falls back to DCR.
- Redirect URI for all hosted apps, mobile included: `https://claude.ai/api/mcp/auth_callback`. Claude Code uses its own CIMD (`https://claude.ai/oauth/claude-code-client-metadata`) with loopback redirects on any port.
- PKCE S256 on every request. Requests the `scope` from the 401 challenge, else `scopes_supported` of the protected resource metadata; adds `offline_access` only if the AS lists it.
- Needs a real 401 (a `WWW-Authenticate` on a 200 is ignored). Uses only the first entry of `authorization_servers`. `resource` in the metadata must equal the URL the user typed.
- Token endpoint must accept `application/x-www-form-urlencoded`, answer within 10 s (refresh 30 s), return `invalid_grant` for a dead refresh token, and rotate refresh tokens for public clients (CIMD and DCR are public clients).
- The exact CIMD URL Claude's hosted apps send is not documented; it is an `https://claude.ai/...` URL.
- Traffic comes from `160.79.104.0/21`.

## ChatGPT

Source: [Apps SDK: Authentication](https://developers.openai.com/apps-sdk/build/auth).

- Supports **CIMD**, **DCR** and a **predefined client**. "ChatGPT prioritizes CIMD when it is available". DCR "is still supported".
- CIMD `client_id`: `https://chatgpt.com/oauth/client.json` when the AS meets the issuer identification requirements (RFC 9207: `authorization_response_iss_parameter_supported: true`, `iss` in every authorization response equal to `issuer`), otherwise `https://chatgpt.com/oauth/{callback_id}/client.json`.
- Redirect URI: `https://chatgpt.com/connector_platform_oauth_redirect` (with RFC 9207), otherwise `https://chatgpt.com/connector/oauth/{callback_id}`.
- Sends `resource` on authorization and token requests and expects it bound into the token. PKCE S256 is mandatory ("MCP servers are unsupported" without it). For CIMD it uses `none` or `private_key_jwt` at the token endpoint.
- Custom connectors need Developer mode; plan availability differs between sources and mobile use is not documented by OpenAI, so ChatGPT mobile is unverified.

## Doorkeeper

Source: [CHANGELOG on main](https://raw.githubusercontent.com/doorkeeper-gem/doorkeeper/main/CHANGELOG.md), [rubygems versions](https://rubygems.org/gems/doorkeeper/versions).

| Need | 5.9.9 (stable) | 6.0.0.rc2 (2026-09-24) | main (unreleased) |
| --- | --- | --- | --- |
| PKCE S256, `force_pkce` for all clients | yes (public only) | yes (#1842) | yes |
| RFC 8414 metadata at `/.well-known/oauth-authorization-server` | no | yes (#1838), `custom_metadata` | yes |
| RFC 8707 `resource`, stored on grants and tokens | no | yes (#1886) | yes |
| RFC 9207 `iss` | no | yes (#1849) | yes |
| CIMD | no | **no** | yes (#1956, #1973 allowlist) |
| `localhost` redirect port ignored (Claude Code) | no | no | yes (#1960) |
| DCR | no (not in core) | no | no |

Cited CVEs: both exist and both are in **doorkeeper-openid_connect**, not core Doorkeeper, and only in its opt-in DCR endpoint:

- [CVE-2026-44476](https://api.osv.dev/v1/vulns/CVE-2026-44476) (GHSA-m6vc-f87m-cc2h): DCR created public clients that were also handed a secret, so the token endpoint skipped the secret. Fixed in doorkeeper-openid_connect 1.10.0.
- [CVE-2026-70665](https://api.osv.dev/v1/vulns/CVE-2026-70665) (GHSA-8r7r-wh7x-27ff): DCR stored client-supplied scopes unchecked. Fixed in doorkeeper-openid_connect 1.10.4. Current release is 2.1.0.

We do not use doorkeeper-openid_connect or DCR, so neither applies. Core Doorkeeper has no open advisory in OSV; the newest is CVE-2023-34246, fixed in 5.6.6.

## Hosted provider comparison (CIMD is required and released Doorkeeper lacks it)

| | A: Doorkeeper 6.0.0.rc2 + own CIMD lookup for allowlisted hosts | B: Doorkeeper pinned to a main commit | C: WorkOS AuthKit, Standalone Connect |
| --- | --- | --- | --- |
| CIMD | ours, ~50 lines: fetch only from `claude.ai` and `chatgpt.com`, no redirects, size and time limits | upstream #1956/#1973 | yes ([docs](https://docs-astro.workos.com/authkit/mcp)) |
| PKCE, RFC 8414, 8707, 9207 | Doorkeeper | Doorkeeper | provider |
| Login | devise session, as now | devise | our login via Standalone Connect, AuthKit issues tokens |
| Token check at `/mcp` | DB lookup, revoke is instant | DB lookup | JWT + JWKS, revoke through the WorkOS API |
| "Assistants" list and revoke | our tables | our tables | WorkOS API calls |
| New dependency | none beyond Doorkeeper | git-sourced gem, unreleased code in the auth path | external service, account, outage dependency |
| Cost | 0 | 0 | free to 1M MAU ([pricing](https://workos.com/pricing.md)) |

C keeps us off our own OAuth code but adds a vendor, a second token format and remote revocation for a single-owner self-hosted app. B puts unreleased code on the auth path. A keeps every OAuth step in Doorkeeper except resolving a CIMD `client_id` into a Doorkeeper application, and the host allowlist removes the SSRF and impersonation surface the CIMD draft warns about. When Doorkeeper 6.0 ships #1956, our lookup is replaced by `use_client_id_metadata_documents` + `allow_client_id_metadata_document`.

## Decision (build only what the clients use)

- **Client registration: CIMD only**, Doorkeeper 6.0.0.rc2 + own allowlisted CIMD lookup (option A). Both target clients prefer CIMD and use it whenever the AS advertises it. Allowed `client_id` hosts: `claude.ai`, `chatgpt.com`.
- **No DCR** (deprecated, not needed once CIMD is advertised, and the cited CVEs live there). **No pre-registered clients**: no UI for them, the user would have to paste ids.
- AS metadata: `client_id_metadata_document_supported: true`, `token_endpoint_auth_methods_supported` includes `none`, `code_challenge_methods_supported: ["S256"]`, `issuer` set so `iss` is returned (ChatGPT stable redirect and client id).
- Protected resource metadata at `/.well-known/oauth-protected-resource` and `/.well-known/oauth-protected-resource/mcp`; `resource` = `APP_URL/mcp`.
- `resource` is required and must equal `APP_URL/mcp`; `/mcp` rejects tokens bound to anything else.
- Refresh tokens rotate on use; access tokens live 1 hour.
- Not supported yet: Claude Code (loopback `localhost` port matching arrives with Doorkeeper main #1960; add `claude.ai/oauth/claude-code-client-metadata` then). Failure mode "client without a supported mechanism": an unknown `client_id` gets Doorkeeper's `invalid_client` error page, per spec.
