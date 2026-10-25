const PREFIX = "bs:cache:"

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
    localStorage.setItem(PREFIX + key, JSON.stringify(value))
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
