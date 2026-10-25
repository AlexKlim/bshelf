require "rails_helper"

RSpec.describe CatalogEntry do
  it "prunes entries past their TTL every day" do
    described_class.fetch("old") { [] }
    described_class.where(key: "old").update_all(updated_at: (described_class::TTL + 1.day).ago)
    described_class.fetch("fresh") { [] }

    described_class.prune

    expect(described_class.pluck(:key)).to eq([ "fresh" ])
    task = YAML.load_file(Rails.root.join("config/recurring.yml")).dig("production", "prune_catalog_entries")
    expect(task).to include("command" => "CatalogEntry.prune", "schedule" => match(/every day/))
  end
end
