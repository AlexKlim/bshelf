const PREFIX = "bs:cache:"
const MAX_CHARS = 1_000_000

export function readCache<T>(key: string): T | null {
  try {
    const raw = localStorage.getItem(PREFIX + key)
    return raw ? (JSON.parse(raw) as T) : null
  } catch {
    return null
  }
}

export function writeCache(key: string, value: unknown) {
  try {
    const json = JSON.stringify(value)
    if (json.length > MAX_CHARS) localStorage.removeItem(PREFIX + key)
    else localStorage.setItem(PREFIX + key, json)
  } catch {
    /* storage full or blocked: the cache is only a convenience */
  }
}

export function clearCaches() {
  try {
    Object.keys(localStorage)
      .filter((k) => k.startsWith(PREFIX))
      .forEach((k) => localStorage.removeItem(k))
  } catch {
    /* nothing cached */
  }
}

export function readPref(key: string) {
  try {
    return localStorage.getItem(`bs:${key}`)
  } catch {
    return null
  }
}

export function writePref(key: string, value: string) {
  try {
    localStorage.setItem(`bs:${key}`, value)
  } catch {
    /* preference stays for this visit only */
  }
}
