import { readFileSync, writeFileSync } from "node:fs"
import { fileURLToPath } from "node:url"

const design = (file) => fileURLToPath(new URL(`../../design/${file}`, import.meta.url))

export function renderTokens(tokens) {
  const value = (v) => String(v).replace(/^\{(.+)\}$/, "var(--$1)")
  const groups = [tokens.color, tokens.spacing, tokens.radius, tokens.size, tokens.shadow]
  const lines = [
    ...groups.flatMap((group) => group.tokens.map((t) => `  --${t.name}: ${value(t.value)};`)),
    ...Object.entries(tokens.type.families).map(([name, family]) => `  --font-${name}: ${family};`),
  ]
  return `/* Book Shelf - generated from design/tokens.json */\n:root {\n${lines.join("\n")}\n}\n`
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  writeFileSync(design("tokens.css"), renderTokens(JSON.parse(readFileSync(design("tokens.json"), "utf8"))))
}
