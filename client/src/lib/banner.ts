import type { Banner } from "./types"

export type BannerEvent = { kind: "offline" } | Banner

const PRIORITY: BannerEvent["kind"][] = ["offline", "source_error", "export_ready", "litres_reminder", "possible_duplicates"]

// The server already picks one banner by priority; offline outranks it, and dismissed keys hide
// a banner until its next event (a new key).
export function pickBanner(events: (BannerEvent | null | undefined)[], dismissed: ReadonlySet<string>) {
  return events
    .filter((e): e is BannerEvent => !!e)
    .filter((e) => e.kind === "offline" || !e.dismissible || !dismissed.has(e.key))
    .sort((a, b) => PRIORITY.indexOf(a.kind) - PRIORITY.indexOf(b.kind))[0]
}
