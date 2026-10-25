import { execFileSync } from "node:child_process"
import { resolve } from "node:path"
import type { APIRequestContext, Page } from "@playwright/test"

const root = resolve(import.meta.dirname, "../..")

export const uniqueEmail = () => `reader-${Date.now()}-${Math.floor(Math.random() * 1e6)}@example.com`

// The confirmation email goes to letter_opener; reading the token from the database is the stable way in.
export function confirmationToken(email: string) {
  return execFileSync(
    "bin/rails",
    ["runner", "print User.find_by!(email: ARGV.first).confirmation_token", email],
    { cwd: root, env: { ...process.env, DATABASE_URL: process.env.E2E_DATABASE_URL ?? process.env.DATABASE_URL }, encoding: "utf8" },
  ).trim()
}

async function csrf(request: APIRequestContext) {
  const state = await request.storageState()
  return decodeURIComponent(state.cookies.find((c) => c.name === "CSRF-TOKEN")?.value ?? "")
}

export async function apiCall(request: APIRequestContext, method: string, path: string, data?: unknown) {
  if (!(await csrf(request))) await request.get("/api/v1/me")
  const response = await request.fetch(`/api/v1${path}`, {
    method,
    data,
    headers: { "X-CSRF-Token": await csrf(request), Accept: "application/json" },
  })
  if (!response.ok()) throw new Error(`${method} ${path}: ${response.status()} ${await response.text()}`)
  return response.status() === 204 ? null : response.json().catch(() => null)
}

export async function signUpAndIn(page: Page, email = uniqueEmail(), password = "longpassword1") {
  await apiCall(page.request, "POST", "/registration", { email, password })
  await apiCall(page.request, "POST", "/confirmation", { token: confirmationToken(email) })
  await apiCall(page.request, "POST", "/session", { email, password })
  return email
}

type Seed = { title: string; author: string; format: "audio" | "ebook"; status: string; finished?: string; started?: string }

export const LIBRARY: Seed[] = [
  { title: "Project Hail Mary", author: "Andy Weir", format: "ebook", status: "in_progress", started: "2026-10-02" },
  { title: "Дюна", author: "Фрэнк Герберт", format: "audio", status: "in_progress", started: "2026-09-20" },
  { title: "Generation «П»", author: "Виктор Пелевин", format: "audio", status: "in_progress" },
  { title: "Норвежский лес", author: "Харуки Мураками", format: "ebook", status: "want" },
  { title: "The Remains of the Day", author: "Kazuo Ishiguro", format: "ebook", status: "want" },
  { title: "Улитка на склоне", author: "Аркадий и Борис Стругацкие", format: "audio", status: "owned" },
  { title: "Мастер и Маргарита", author: "Михаил Булгаков", format: "audio", status: "done", finished: "2026-03-10" },
  { title: "Sapiens", author: "Yuval Noah Harari", format: "ebook", status: "done", finished: "2026-05-02" },
  { title: "Пикник на обочине", author: "Аркадий и Борис Стругацкие", format: "audio", status: "done", finished: "2026-04-11" },
  { title: "Анна Каренина", author: "Лев Толстой", format: "audio", status: "done", finished: "2026-07-21" },
  { title: "Thinking, Fast and Slow", author: "Daniel Kahneman", format: "audio", status: "done", finished: "2026-02-14" },
  { title: "Мессия Дюны", author: "Фрэнк Герберт", format: "audio", status: "done", finished: "2026-06-01" },
  { title: "Klara and the Sun", author: "Kazuo Ishiguro", format: "ebook", status: "done", finished: "2026-08-08" },
  { title: "Солярис", author: "Станислав Лем", format: "ebook", status: "done", finished: "2026-01-19" },
  { title: "The Left Hand of Darkness", author: "Ursula K. Le Guin", format: "ebook", status: "done", finished: "2025-11-03" },
  { title: "Трудно быть богом", author: "Аркадий и Борис Стругацкие", format: "audio", status: "done", finished: "2025-09-15" },
  { title: "Never Let Me Go", author: "Kazuo Ishiguro", format: "ebook", status: "done", finished: "2025-04-04" },
  { title: "Белая гвардия", author: "Михаил Булгаков", format: "audio", status: "done", finished: "2025-02-22" },
  { title: "Educated", author: "Tara Westover", format: "audio", status: "done", finished: "2025-06-30" },
  { title: "Понедельник начинается в субботу", author: "Аркадий и Борис Стругацкие", format: "ebook", status: "done", finished: "2024-12-12" },
  { title: "Atomic Habits", author: "James Clear", format: "audio", status: "done", finished: "2024-03-10" },
  { title: "Преступление и наказание", author: "Фёдор Достоевский", format: "ebook", status: "done" },
]

export async function seedLibrary(request: APIRequestContext, books = LIBRARY) {
  for (const b of books) {
    await apiCall(request, "POST", "/books", {
      title: b.title,
      author: b.author,
      edition: { format: b.format, status: b.status, finished_at: b.finished, started_at: b.started },
    })
  }
}
