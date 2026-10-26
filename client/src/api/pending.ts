import { api, ApiError } from "@/lib/api"

export const notOfferedYet = (e: unknown) => e instanceof ApiError && (e.status === 501 || e.status === 404)

export type SyncResult = { books: number; highlights: number }

export const requestKindleExport = () => api<void>("/sources/kindle_export/request", { method: "POST" })

export const uploadKindleExport = (file: File) => {
  const body = new FormData()
  body.append("archive", file)
  return api<SyncResult>("/sources/kindle_export/upload", { method: "POST", body })
}
