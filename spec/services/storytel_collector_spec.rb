require "rails_helper"

RSpec.describe StorytelCollector do
  it "only trusts pages from storytel.com" do
    storytel = ->(host) { described_class.new.send(:storytel?, host) }

    expect(%w[storytel.com www.storytel.com .storytel.com].map(&storytel)).to all(be(true))
    expect([ "accounts.google.com", "notstorytel.com", "storytel.com.evil.com", nil ].map(&storytel)).to all(be(false))
  end
end
