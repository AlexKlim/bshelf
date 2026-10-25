import type { Banner } from "./types"
import { pickBanner } from "./banner"

const error: Banner = { kind: "source_error", source: "litres", error: "needs_login", dismissible: false, key: "source_error:litres:1" }
const reminder: Banner = { kind: "litres_reminder", dismissible: true, key: "litres_reminder:1" }
const dupes: Banner = { kind: "possible_duplicates", count: 3, dismissible: true, key: "possible_duplicates:7" }

describe("banner slot", () => {
  it("shows only the highest priority event", () => {
    expect(pickBanner([dupes, reminder, error], new Set())).toBe(error)
    expect(pickBanner([dupes, reminder], new Set())).toBe(reminder)
  })

  it("puts no network above everything", () => {
    expect(pickBanner([error, { kind: "offline" }], new Set())?.kind).toBe("offline")
  })

  it("never hides a source error, even if its key was dismissed", () => {
    expect(pickBanner([error], new Set([error.key]))).toBe(error)
  })

  it("hides a dismissed banner until its next event", () => {
    const dismissed = new Set([dupes.key])
    expect(pickBanner([dupes], dismissed)).toBeUndefined()
    expect(pickBanner([{ ...dupes, key: "possible_duplicates:8" }], dismissed)?.kind).toBe("possible_duplicates")
  })

  it("falls through to the next event when the top one is dismissed", () => {
    expect(pickBanner([reminder, dupes], new Set([reminder.key]))).toBe(dupes)
  })

  it("is empty with nothing to say", () => {
    expect(pickBanner([null, undefined], new Set())).toBeUndefined()
  })
})
