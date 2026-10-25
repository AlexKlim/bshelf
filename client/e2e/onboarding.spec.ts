import { expect, test, type Locator, type Page } from "@playwright/test"
import { fileURLToPath } from "node:url"
import { confirmationToken, uniqueEmail } from "./helpers"

// The cloth comes from a hash of the random book id; pin it so the snapshots compare the book, not the colour.
const stylePath = fileURLToPath(new URL("./snapshot.css", import.meta.url))

// The baselines are rendered on macOS; Linux draws the same fonts differently, so CI checks behaviour only.
const snapshot = (locator: Locator, name: string) =>
  process.platform === "darwin" ? expect(locator).toHaveScreenshot(name, { stylePath }) : Promise.resolve()

async function settle(page: Page) {
  await page.evaluate(() => document.fonts.ready)
  await expect(page.getByRole("dialog").locator(".bs-spread")).toBeVisible()
  await expect(page.locator(".bs-flap")).toHaveCount(0)
}

test("register, add the first book, find it on the right shelf and open it", async ({ page, browser }) => {
  const email = uniqueEmail()
  const password = "longpassword1"

  await page.goto("/register")
  await page.getByLabel("Email", { exact: true }).fill(email)
  await page.getByLabel("Password", { exact: true }).fill(password)
  await page.getByRole("button", { name: "Create account" }).click()
  await expect(page.getByRole("heading", { name: "Check your email" })).toBeVisible()

  await page.goto(`/confirm?token=${confirmationToken(email)}`)
  await expect(page.getByRole("heading", { name: "Email confirmed" })).toBeVisible()
  await page.getByRole("link", { name: "Sign in" }).click()

  await page.getByLabel("Email", { exact: true }).fill(email)
  await page.getByLabel("Password", { exact: true }).fill(password)
  await page.getByRole("button", { name: "Sign in" }).click()

  await expect(page.getByRole("heading", { name: "The bookcase is empty for now" })).toBeVisible()
  await page.getByRole("button", { name: "Add book" }).click()

  const form = page.getByRole("dialog")
  await form.getByLabel("Title").fill("Solaris")
  await form.getByLabel("Author").fill("Stanisław Lem")
  await form.getByRole("radio", { name: "Audio" }).check()
  await form.getByRole("radio", { name: "Listened" }).check()
  await form.getByLabel("When").fill("2024-03")
  await form.getByRole("button", { name: "Write it in" }).click()
  await expect(form).toBeHidden()

  const shelf = page.getByRole("region", { name: "2024 · 1" })
  const spine = shelf.locator(".bs-spine")
  await expect(spine).toHaveAccessibleName("Solaris, Stanisław Lem. Listened, Mar 2024")
  await expect(page.getByRole("region", { name: "Now · 0" })).toBeVisible()

  await spine.click()
  await expect(spine).toHaveAttribute("aria-expanded", "true")
  await shelf.locator(".bs-caption").click()

  await settle(page)
  const spread = page.locator(".bs-book")
  await expect(spread.getByRole("heading", { name: "Solaris", level: 1 })).toBeVisible()
  await expect(spread.getByText("Audio. Listened · Mar 2024")).toBeVisible()
  await snapshot(spread, "spread-390.png")

  const bookUrl = page.url()
  for (const width of [900, 1440]) {
    const context = await browser.newContext({
      storageState: await page.context().storageState(),
      viewport: { width, height: 900 },
      isMobile: false,
      hasTouch: false,
      deviceScaleFactor: 1,
    })
    const desktop = await context.newPage()
    await desktop.goto(bookUrl)
    await settle(desktop)
    await snapshot(desktop.locator(".bs-book"), `spread-${width}.png`)
    await context.close()
  }
})
