require "rails_helper"

RSpec.describe "Librarian's desk" do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }

  before do
    sign_in_as(user)
    allow(JevClient).to receive(:configured?).and_return(true)
  end

  it "queues the lookup for the reader's books that miss something, and only theirs" do
    never = create(:book, user:)
    coverless = create(:book, user:, enriched_at: 1.day.ago)
    colourless = create(:book, user:, enriched_at: 1.day.ago, cover_url: "https://www.litres.ru/a.jpg")
    create(:book, user:, enriched_at: 1.day.ago, cover_url: "https://www.litres.ru/b.jpg").update_columns(cloth_color: "#d30535")
    file_name = create(:book, user:, title: "51318-doch-dyima-i-kostey", enriched_at: 1.day.ago, cover_url: "https://www.litres.ru/c.jpg")
    file_name.update_columns(cloth_color: "#d30535")
    create(:book)
    clear_enqueued_jobs

    post "/api/v1/library/tidy", as: :json

    expect(response).to have_http_status(:ok)
    expect(json).to eq("queued" => 4, "duplicates" => true)
    enriched = enqueued_jobs.select { it["job_class"] == "EnrichBookJob" }.map { it["arguments"].first }
    expect(enriched).to contain_exactly(never.id, coverless.id, colourless.id, file_name.id)
    expect(FindTranslationsJob).to have_been_enqueued.with(user.id)
    expect(BookGenresJob).to have_been_enqueued.with(user.id)
  end
end
