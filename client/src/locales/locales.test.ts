import { readFileSync } from "node:fs"
import { resolve } from "node:path"
import en from "./en/common.json"
import ru from "./ru/common.json"

function keys(obj: object, prefix = ""): string[] {
  return Object.entries(obj).flatMap(([k, v]) =>
    typeof v === "object" && v !== null ? keys(v, `${prefix}${k}.`) : [`${prefix}${k}`],
  )
}

const base = (all: string[]) => [...new Set(all.map((k) => k.replace(/_(one|few|many|other)$/, "")))].sort()

it("has the same keys in EN and RU", () => {
  expect(base(keys(ru))).toEqual(base(keys(en)))
})

it("gives every Russian plural all four forms", () => {
  const plurals = base(keys(ru).filter((k) => /_(one|few|many|other)$/.test(k)))
  for (const key of plurals) {
    expect(["one", "few", "many", "other"].map((f) => `${key}_${f}`).every((k) => keys(ru).includes(k))).toBe(true)
  }
})

it("translates every error code listed in API.md", () => {
  const doc = readFileSync(resolve(__dirname, "../../../API.md"), "utf8")
  const section = doc.split("## Error codes")[1].split("##")[0]
  const codes = [...section.matchAll(/`(\w+)`/g)].map((m) => m[1])

  expect(codes.length).toBeGreaterThan(10)
  expect(codes.filter((code) => !(code in en.errors))).toEqual([])
})
