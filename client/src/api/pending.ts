import { api } from "@/lib/api"

export type SyncResult = { books: number; highlights: number }

export const syncLitres = (login: string, password: string) =>
  api<SyncResult>("/sources/litres/sync", { method: "POST", body: { login, password } })

export const requestKindleExport = () => api<void>("/sources/kindle_export/request", { method: "POST" })

export const uploadKindleExport = (file: File) => {
  const body = new FormData()
  body.append("archive", file)
  return api<SyncResult>("/sources/kindle_export/upload", { method: "POST", body })
}
