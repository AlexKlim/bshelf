import { expect, test, type Page } from "@playwright/test"
import { seedLibrary, signUpAndIn } from "./helpers"

async function throwAway(page: Page, title: string) {
  const spine = page.locator(".bs-spine", { hasText: title })
  await spine.scrollIntoViewIfNeeded()
  const from = (await spine.boundingBox())!
  await page.mouse.move(from.x + from.width / 2, from.y + from.height / 2)
  await page.mouse.down()
  await page.mouse.move(from.x + 40, from.y + 40, { steps: 5 })
  const bin = (await page.locator(".bs-bin").boundingBox())!
  await page.mouse.move(bin.x + bin.width / 2, bin.y + bin.height / 2, { steps: 10 })
  await expect(page.locator(".bs-bin")).toHaveClass(/is-over/)
  await page.mouse.up()
}

test("a book dragged into the trash can be brought back, or goes for good", async ({ browser, baseURL }) => {
  const context = await browser.newContext({ viewport: { width: 1280, height: 900 }, isMobile: false, hasTouch: false, baseURL })
  const page = await context.newPage()
  await page.addInitScript(() => localStorage.setItem("i18nextLng", "en"))
  await signUpAndIn(page)
  await seedLibrary(page.request, [
    { title: "Solaris", author: "Stanisław Lem", format: "ebook", status: "done", finished: "2025-03-01" },
    { title: "Dune", author: "Frank Herbert", format: "ebook", status: "done", finished: "2025-04-01" },
  ] as never)
  await page.goto("/")
  await expect(page.locator(".bs-spine", { hasText: "Solaris" })).toBeVisible()
  await expect(page.locator(".bs-bin")).toBeHidden()

  await throwAway(page, "Solaris")
  await expect(page.locator(".bs-spine", { hasText: "Solaris" })).toHaveCount(0)
  await page.getByRole("button", { name: "Undo" }).click()
  await expect(page.locator(".bs-spine", { hasText: "Solaris" })).toBeVisible()

  const deleted = page.waitForResponse((r) => r.request().method() === "DELETE", { timeout: 10_000 })
  await throwAway(page, "Solaris")
  await expect(page.getByRole("status")).toContainText("Solaris")
  expect((await deleted).status()).toBe(204)
  await page.reload()
  await expect(page.locator(".bs-spine", { hasText: "Dune" })).toBeVisible()
  await expect(page.locator(".bs-spine", { hasText: "Solaris" })).toHaveCount(0)
})
