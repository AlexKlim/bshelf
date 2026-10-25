import { readPref, writePref } from "./cache"

const TTL = 60 * 60 * 1000

// Only the server-rendered OAuth consent page is a valid target (API.md, SPA contract); anything else,
// including "//host" and "/\host", is ignored so the login cannot be used as an open redirect.
export function oauthReturnTo(value: string | null | undefined) {
  if (!value || !value.startsWith("/oauth/authorize") || value.includes("\\")) return null
  return value
}

// Kept across sign up and email confirmation, which happen in another tab or later.
export function rememberReturnTo(value: string | null) {
  const path = oauthReturnTo(value)
  if (path) writePref("return_to", JSON.stringify({ path, at: Date.now() }))
}

export function takeReturnTo(param: string | null) {
  const fromParam = oauthReturnTo(param)
  let stored: string | null = null
  try {
    const saved = JSON.parse(readPref("return_to") ?? "null") as { path: string; at: number } | null
    if (saved && Date.now() - saved.at < TTL) stored = oauthReturnTo(saved.path)
  } catch {
    stored = null
  }
  writePref("return_to", "null")
  return fromParam ?? stored
}
