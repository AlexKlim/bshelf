require "rails_helper"

RSpec.describe ShelfMove do
  let(:user) { create(:user) }
  let(:shelf) { Shelf.new(user) }

  def done(title, on) = create(:book, user:, title:, status: "done", finished_at: on)
  def row(key) = shelf.page(key, offset: 0, limit: 50)[:books].pluck(:title)

  around { |example| travel_to(Time.zone.local(2026, 10, 26, 12)) { example.run } }

  it "dates a book dropped between two read the same year so it stays between them" do
    newer = done("Newer", Time.zone.local(2026, 9, 1))
    older = done("Older", Time.zone.local(2026, 3, 1))
    moved = create(:book, user:, title: "Moved", status: "in_progress")

    described_class.call(moved, key: "2026", before: newer, after: older)

    expect(row("2026")).to eq(%w[Newer Moved Older])
    expect(moved.editions.first.reading.reload.finished_at).to eq(Time.zone.local(2026, 6, 1))
  end

  it "keeps the dropped place between two books read on the same day" do
    newer, older = %w[Newer Older].map { done(it, Time.zone.local(2026, 5, 1)) }
    newer.editions.first.reading.update_columns(updated_at: 1.hour.ago)
    older.editions.first.reading.update_columns(updated_at: 2.hours.ago)
    moved = create(:book, user:, title: "Moved", status: "want")

    described_class.call(moved, key: "2026", before: newer, after: older)

    expect(row("2026")).to eq(%w[Newer Moved Older])
  end

  it "keeps a past year's date inside that year at either end" do
    only = done("Only", Time.zone.local(2019, 1, 1, 6))
    moved = create(:book, user:, title: "Moved", status: "want")

    described_class.call(moved, key: "2019", before: only)

    expect(row("2019")).to eq(%w[Only Moved])
    expect(moved.editions.first.reading.reload.finished_at).to eq(Time.zone.local(2019, 1, 1))
  end

  it "keeps a hand-placed book in its place on a shelf ordered by activity, until it leaves the shelf" do
    first, second, moved = %w[First Second Moved].map { create(:book, user:, title: it, status: "in_progress") }
    { first => 2.hours, second => 3.hours, moved => 1.hour }.each { |b, ago| b.editions.first.reading.update_columns(updated_at: ago.ago) }

    described_class.call(moved, key: "now", before: first, after: second)
    expect(row("now")).to eq(%w[First Moved Second])

    StatusResolver.manual!(moved.editions.first.reading, status: "done")
    StatusResolver.manual!(moved.editions.first.reading, status: "in_progress")
    expect(row("now").first).to eq("Moved")
  end

  it "puts a store copy on the owned shelf and a wish on the want shelf" do
    store = create(:book, user:, title: "Store", status: "done", finished_at: Time.zone.local(2025, 1, 1))
    store.editions.first.update!(store: "litres", external_id: "1")

    described_class.call(store, key: "want")

    expect(shelf.key_for(store)).to eq("owned")
  end
end
