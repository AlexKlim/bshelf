require "rails_helper"

RSpec.describe EnrichBookJob do
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  let(:book) { create(:book, title: "Солярис", author: "Станислав Лем") }

  before do
    stub_open_library("open_library_solyaris.json")
    clear_enqueued_jobs
  end

  it "is enqueued for every new book and never runs inside the request" do
    expect { create(:book) }.to have_enqueued_job(described_class)
  end

  it "hands matching to its own job so the catalog slot is free for the next lookup" do
    stub_google("google_429.json", status: 429)
    book.update!(cover_url: "https://cv1.litres.ru/cover.jpg")
    stub_request(:get, "https://cv1.litres.ru/cover.jpg").to_return(status: 404)
    clear_enqueued_jobs
    allow(BookMatcher).to receive(:call)

    expect { described_class.perform_now(book.id) }.to have_enqueued_job(MatchBookJob).with(book)
    expect(BookMatcher).not_to have_received(:call)

    MatchBookJob.perform_now(book)
    expect(BookMatcher).to have_received(:call).with(book)
  end

  it "backs off on 429, honouring Retry-After, then gives up" do
    stub_google("google_429.json", status: 429, headers: { "Retry-After" => "600" })
    freeze_time

    expect { described_class.perform_now(book.id) }
      .to have_enqueued_job(described_class).with(book.id).at(10.minutes.from_now)

    job = described_class.new(book.id)
    job.executions = described_class::RATE_LIMIT_ATTEMPTS - 1
    expect { job.perform_now }.to raise_error(CatalogClient::RateLimited)
    expect(book.reload.enriched_at).to be_nil
  end

  it "backs off exponentially without Retry-After" do
    stub_google("google_429.json", status: 429)
    freeze_time
    job = described_class.new(book.id)
    job.executions = 2

    expect { job.perform_now }.to have_enqueued_job(described_class).at(8.minutes.from_now)
  end

  it "re-picks the cloth when a sync replaces the cover" do
    book.update!(cloth: "navy")
    clear_enqueued_jobs

    expect { book.update!(cover_url: "https://cv1.litres.ru/cover.jpg") }.to have_enqueued_job(described_class)
    expect(book.reload.cloth).to be_nil
  end
end
