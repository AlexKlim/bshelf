require "rails_helper"

RSpec.describe ReadCoverColorsJob do
  include ActiveJob::TestHelper

  it "queues the books whose cover has no colour yet" do
    without = create(:book, cover_url: "https://www.litres.ru/a.jpg")
    create(:book, cover_url: "https://www.litres.ru/b.jpg").update_columns(cloth_color: "#d30535")
    create(:book)
    clear_enqueued_jobs

    described_class.perform_now

    expect(enqueued_jobs.map { it["arguments"] }).to eq([ [ without.id ] ])
  end
end
