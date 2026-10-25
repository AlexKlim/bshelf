import { readFileSync } from "node:fs"
import { resolve } from "node:path"
import { renderTokens } from "../scripts/tokens.mjs"

it("keeps design/tokens.css generated from design/tokens.json (npm run tokens)", () => {
  const read = (file: string) => readFileSync(resolve(__dirname, "../../design", file), "utf8")
  expect(read("tokens.css")).toBe(renderTokens(JSON.parse(read("tokens.json"))))
})
