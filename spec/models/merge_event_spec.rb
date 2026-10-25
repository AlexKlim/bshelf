require "rails_helper"

RSpec.describe MergeEvent do
  let(:user) { create(:user) }

  def book_with_edition(title:, format:, store:, status:, **attrs)
    book = create(:book, user:, title:, **attrs)
    source = { "litres" => "litres", "amazon" => "kindle_export" }.fetch(store, "manual")
    edition = create(:edition, book:, format:, store:, source:, external_id: store && SecureRandom.hex(4))
    reading = create(:reading, edition:, status:, status_source: source,
      finished_at: (Time.zone.parse("2024-03-10 12:34:56.123456") if status == "done"))
    StatusChange.create!(user:, reading:, to_status: status, source: reading.status_source)
    book
  end

  def snapshot(book)
    book.reload
    {
      book: book.attributes.except("updated_at"),
      editions: book.editions.order(:id).map { it.attributes.except("updated_at") },
      readings: book.readings.order(:id).map(&:attributes),
      status_changes: StatusChange.where(reading_id: book.readings.ids).order(:id).map(&:attributes),
      notes: book.notes.order(:id).map(&:attributes),
      highlights: book.highlights.order(:id).map(&:attributes)
    }
  end

  let!(:survivor) { book_with_edition(title: "Солярис", format: "audio", store: "litres", status: "done") }
  let!(:absorbed) do
    book_with_edition(title: "Solaris", format: "ebook", store: "amazon", status: "in_progress",
      isbn: "9780156027601", cover_url: "https://covers.openlibrary.org/b/id/1-L.jpg", cloth: "navy", year: 1961)
  end

  before do
    create(:note, book: survivor, body: "Ocean")
    create(:note, book: absorbed, body: "Kelvin")
    create(:highlight, book: absorbed)
  end

  it "moves everything to the survivor and fills only its blanks" do
    survivor.update!(year: 1972)

    event = described_class.merge!(survivor, absorbed)

    expect(Book.exists?(absorbed.id)).to be(false)
    expect(survivor.reload).to have_attributes(isbn: "9780156027601", cloth: "navy", year: 1972)
    expect(survivor.editions.map(&:format)).to contain_exactly("audio", "ebook")
    expect(survivor.readings.map(&:status)).to contain_exactly("done", "in_progress")
    expect(survivor.notes.map(&:body)).to contain_exactly("Ocean", "Kelvin")
    expect(survivor.highlights.count).to eq(1)
    expect(event.filled.keys).to contain_exactly("isbn", "cover_url", "cloth")
  end

  it "unmerges back to the exact original books and statuses" do
    before_survivor = snapshot(survivor)
    before_absorbed = snapshot(absorbed)

    event = described_class.merge!(survivor, absorbed)
    survivor_after, restored = event.unmerge!

    expect(restored).to have_attributes(id: absorbed.id, uuid: absorbed.uuid)
    expect(snapshot(survivor_after)).to eq(before_survivor)
    expect(snapshot(restored)).to eq(before_absorbed)
    expect(event.reload.unmerged_at).to be_present
    expect(event.unmerge!).to be_nil
  end

  it "keeps what the user changed on the survivor after the merge" do
    event = described_class.merge!(survivor, absorbed)
    survivor.reload.update!(isbn: "9785171021906")
    note = create(:note, book: survivor, body: "Added later")

    event.unmerge!

    expect(survivor.reload).to have_attributes(isbn: "9785171021906", cover_url: nil, cloth: nil)
    expect(survivor.notes).to include(note)
  end

  it "remembers an unmerged pair so the matcher never merges it again" do
    event = described_class.merge!(survivor, absorbed)
    _, restored = event.unmerge!
    survivor.update!(isbn: restored.isbn)

    BookMatcher.call(survivor)

    expect(Book.exists?(restored.id)).to be(true)
    expect(DuplicateCandidate.open.count).to eq(0)
  end

  it "hands the absorbed book's possible duplicates to the survivor and gives them back on unmerge" do
    open_other = create(:book, user:, title: "Солярис (сборник)")
    dismissed_other = create(:book, user:, title: "Solaris (film)")
    open_pair = DuplicateCandidate.record!(absorbed, open_other, reason: "title")
    dismissed_pair = DuplicateCandidate.record!(absorbed, dismissed_other, reason: "title_author", dismissed_at: 1.day.ago)
    before = [ open_pair, dismissed_pair ].map { it.reload.attributes }

    event = described_class.merge!(survivor, absorbed)

    pairs = DuplicateCandidate.involving(survivor).map { [ it.other_id(survivor), it.reason, it.dismissed_at.present? ] }
    expect(pairs).to contain_exactly([ open_other.id, "title", false ], [ dismissed_other.id, "title_author", true ])

    event.unmerge!

    expect(DuplicateCandidate.where(id: before.map { it["id"] }).map(&:attributes)).to match_array(before)
    expect(DuplicateCandidate.involving(survivor).map { [ it.other_id(survivor), it.dismissed_at.present? ] })
      .to eq([ [ absorbed.id, true ] ])
  end

  describe "chained merges" do
    let!(:third) { book_with_edition(title: "Solaris (film tie-in)", format: "audio", store: nil, status: "want") }
    let!(:before) { [ survivor, absorbed, third ].map { snapshot(it) } }
    let!(:first) { described_class.merge!(survivor, absorbed) }
    let!(:second) { described_class.merge!(third, survivor) }

    it "restores everything exactly when undone newest first" do
      second.reload.unmerge!
      first.reload.unmerge!

      expect([ survivor, absorbed, third ].map { snapshot(Book.find(it.id)) }).to eq(before)
    end

    it "restores editions, statuses and notes when undone oldest first" do
      first.reload.unmerge!
      second.reload.unmerge!

      after = [ survivor, absorbed, third ].map { snapshot(Book.find(it.id)) }
      expect(after.map { it.except(:book) }).to eq(before.map { it.except(:book) })
    end
  end
end
