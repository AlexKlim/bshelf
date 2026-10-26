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
end
