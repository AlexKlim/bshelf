import { readFileSync } from "node:fs"
import { resolve } from "node:path"
import en from "./en/common.json"
import ru from "./ru/common.json"

function keys(obj: object, prefix = ""): string[] {
  return Object.entries(obj).flatMap(([k, v]) =>
    typeof v === "object" && v !== null ? keys(v, `${prefix}${k}.`) : [`${prefix}${k}`],
  )
}

it("has the same keys in EN and RU", () => {
  expect(keys(ru).sort()).toEqual(keys(en).sort())
})

it("translates every error code listed in API.md", () => {
  const doc = readFileSync(resolve(__dirname, "../../../API.md"), "utf8")
  const section = doc.split("## Error codes")[1].split("##")[0]
  const codes = [...section.matchAll(/`(\w+)`/g)].map((m) => m[1])

  expect(codes.length).toBeGreaterThan(10)
  expect(codes.filter((code) => !(code in en.errors))).toEqual([])
})
