const KEY = "bs:chunk-reload"
const WINDOW_MS = 10_000

export const page = { reload: () => window.location.reload() }

export function isChunkError(error: unknown) {
  return (
    error instanceof Error &&
    /dynamically imported module|Importing a module script failed|Unable to preload CSS|ChunkLoadError/i.test(`${error.name} ${error.message}`)
  )
}

export function reloadOnce() {
  try {
    if (Date.now() - Number(sessionStorage.getItem(KEY) ?? 0) < WINDOW_MS) return false
    sessionStorage.setItem(KEY, String(Date.now()))
  } catch {
    return false
  }
  page.reload()
  return true
}
