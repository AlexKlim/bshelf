import { readPref, writePref } from "./cache"

const TTL = 60 * 60 * 1000

export function oauthReturnTo(value: string | null | undefined) {
  if (!value || !value.startsWith("/oauth/authorize") || value.includes("\\")) return null
  return value
}

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
