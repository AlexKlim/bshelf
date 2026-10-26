import i18n from "../i18n"

export type ApiErrorItem = { code: string; field?: string }

export class ApiError extends Error {
  readonly status: number
  readonly errors: ApiErrorItem[]
  readonly body: Record<string, unknown>

  constructor(status: number, body: Record<string, unknown>) {
    const errors = Array.isArray(body.errors) ? (body.errors as ApiErrorItem[]) : [{ code: "generic" }]
    super(errors[0].code)
    this.status = status
    this.errors = errors
    this.body = body
  }

  get code() {
    return this.errors[0].code
  }
}

type Method = "GET" | "POST" | "PATCH" | "PUT" | "DELETE"

function csrfToken() {
  const match = document.cookie.match(/(?:^|;\s*)CSRF-TOKEN=([^;]+)/)
  return match ? decodeURIComponent(match[1]) : undefined
}

export const UNAUTHORIZED_EVENT = "bs:unauthorized"

export async function api<T>(path: string, options: { method?: Method; body?: unknown } = {}): Promise<T> {
  const method = options.method ?? "GET"
  const form = options.body instanceof FormData
  const headers: Record<string, string> = { Accept: "application/json", "Accept-Language": i18n.language }
  if (options.body !== undefined && !form) headers["Content-Type"] = "application/json"
  const token = csrfToken()
  if (method !== "GET" && token) headers["X-CSRF-Token"] = token

  let response: Response
  try {
    response = await fetch(`/api/v1${path}`, {
      method,
      headers,
      credentials: "same-origin",
      body: options.body === undefined ? undefined : form ? (options.body as FormData) : JSON.stringify(options.body),
    })
  } catch {
    throw new ApiError(0, { errors: [{ code: "network" }] })
  }

  if (response.status === 204) return undefined as T
  const body = await response.json().catch(() => ({}))
  if (!response.ok) {
    if (response.status === 401) window.dispatchEvent(new Event(UNAUTHORIZED_EVENT))
    throw new ApiError(response.status, body)
  }
  return body as T
}
