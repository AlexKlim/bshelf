require "rails_helper"

RSpec.describe LitresCollector do
  it "follows the reported next page as is, fixing only its /api/ prefix" do
    next_url = ->(path) { described_class.new.send(:next_url, path) }

    expect(next_url.("/api/users/me/arts?after=YWJj+ZA==&limit=24"))
      .to eq("https://api.litres.ru/foundation/api/users/me/arts?after=YWJj+ZA==&limit=24")
    expect(next_url.("https://api.litres.ru/foundation/api/users/me/arts?after=x"))
      .to eq("https://api.litres.ru/foundation/api/users/me/arts?after=x")
    expect(next_url.(nil)).to be_nil
  end

  it "only trusts pages and cookies from litres.ru" do
    litres = ->(host) { described_class.new.send(:litres?, host) }

    expect(%w[litres.ru .litres.ru www.litres.ru api.litres.ru].map(&litres)).to all(be(true))
    expect([ "accounts.google.com", ".google.com", "notlitres.ru", "litres.ru.evil.com", nil ].map(&litres)).to all(be(false))
  end
end
