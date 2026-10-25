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
