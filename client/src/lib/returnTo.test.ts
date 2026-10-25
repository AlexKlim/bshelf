import { oauthReturnTo, rememberReturnTo, takeReturnTo } from "./returnTo"

describe("return_to after sign in", () => {
  beforeEach(() => localStorage.clear())

  it("accepts only the OAuth consent page", () => {
    expect(oauthReturnTo("/oauth/authorize?client_id=x")).toBe("/oauth/authorize?client_id=x")
    expect(oauthReturnTo("/stats")).toBeNull()
    expect(oauthReturnTo("//evil.example/oauth/authorize")).toBeNull()
    expect(oauthReturnTo("https://evil.example/oauth/authorize")).toBeNull()
    expect(oauthReturnTo("/oauth/authorize\\@evil")).toBeNull()
  })

  it("keeps it through sign up and confirmation, then forgets it", () => {
    rememberReturnTo("/oauth/authorize?a=1")
    expect(takeReturnTo(null)).toBe("/oauth/authorize?a=1")
    expect(takeReturnTo(null)).toBeNull()
  })
})
