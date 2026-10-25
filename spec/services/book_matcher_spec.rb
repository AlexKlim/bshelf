require "rails_helper"

RSpec.describe BookMatcher do
  let(:user) { create(:user) }

  def book(**attrs) = create(:book, user:, status: "owned", **attrs)

  it "normalizes ISBN-10 to ISBN-13" do
    expect(described_class.isbn13("0-15-602760-7")).to eq("9780156027601")
    expect(described_class.isbn13("978-0-15-602760-1")).to eq("9780156027601")
    expect(described_class.isbn13("123")).to be_nil
  end

  it "merges a confident ISBN match into the older book" do
    older = book(title: "Solaris", author: "Stanisław Lem", isbn: "0156027607")
    newer = book(title: "Solaris: a novel", author: nil, isbn: "9780156027601")

    described_class.call(newer)

    expect(Book.exists?(newer.id)).to be(false)
    expect(older.reload.editions.count).to eq(2)
    expect(MergeEvent.last).to have_attributes(book_id: older.id)
  end

  it "merges on the same original title and author" do
    older = book(title: "Солярис", author: "Lem, Stanisław", original_title: "Solaris")
    newer = book(title: "Solaris (Polish)", author: "Stanisław Lem", original_title: "Solaris")

    described_class.call(newer)

    expect(user.books.ids).to eq([ older.id ])
  end

  it "only proposes, never merges, on an ISBN the catalog supplied" do
    older = book(title: "Dune", author: "Frank Herbert", isbn: "9780441013593")
    newer = book(title: "Dune", author: "Frank Herbert", isbn: "9780441013593", isbn_source: "catalog")

    described_class.call(newer)

    expect(user.books.count).to eq(2)
    expect(DuplicateCandidate.sole).to have_attributes(book_id: older.id, other_book_id: newer.id, reason: "title_author")
  end

  it "still merges a catalog ISBN match with the same original title and author" do
    older = book(title: "Солярис", author: "Stanisław Lem", original_title: "Solaris", isbn: "9780156027601",
      isbn_source: "catalog")
    newer = book(title: "Solaris", author: "Lem, Stanisław", original_title: "Solaris", isbn: "9780156027601",
      isbn_source: "catalog")

    described_class.call(newer)

    expect(user.books.ids).to eq([ older.id ])
    expect(DuplicateCandidate.count).to eq(0)
  end

  it "does not merge on an original title that has no letters or digits" do
    book(title: "Eden", author: "Stanisław Lem")
    newer = book(title: "Солярис", author: "Stanisław Lem", original_title: "...")

    described_class.call(newer)

    expect(user.books.count).to eq(2)
  end

  it "compares only books that share an ISBN or a title's first word" do
    target = book(title: "Dune Messiah", author: "Frank Herbert", isbn: "0-441-17269-7")
    book(title: "Dune", author: "Frank Herbert")
    by_isbn = book(title: "Мессия Дюны", author: "Фрэнк Герберт", isbn: "9780441172696")
    %w[Eden Solaris Fiasco Golem Cyberiad].each { book(title: it, author: "Stanisław Lem") }
    allow(TextKey).to receive(:authors).and_call_original

    described_class.call(target)

    # Dune, the ISBN twin, then Dune again in the rerun after the merge; never the five Lem books.
    expect(TextKey).to have_received(:authors).exactly(3).times
    expect(Book.exists?(by_isbn.id)).to be(false)
  end

  it "only proposes a shared title with the same author" do
    a = book(title: "Dune", author: "Frank Herbert")
    b = book(title: "DUNE.", author: "Herbert, Frank")

    described_class.call(b)

    expect(DuplicateCandidate.sole).to have_attributes(book_id: a.id, other_book_id: b.id, reason: "title_author")
  end

  it "proposes a Russian and an English edition matched through the original title" do
    ru = book(title: "Солярис", author: "Станислав Лем", original_title: "Solaris")
    en = book(title: "Solaris", author: "Stanisław Lem")

    described_class.call(en)

    expect(DuplicateCandidate.sole).to have_attributes(book_id: ru.id, reason: "title")
    expect(user.books.count).to eq(2)
  end

  it "ignores the same title by a different author" do
    book(title: "Solaris", author: "Stanisław Lem")
    other = book(title: "Solaris", author: "Andrei Tarkovsky")

    described_class.call(other)

    expect(DuplicateCandidate.count).to eq(0)
  end

  it "does not propose a pair twice or after it was dismissed" do
    a = book(title: "Dune", author: "Frank Herbert")
    b = book(title: "Dune", author: "Frank Herbert")
    described_class.call(b)
    DuplicateCandidate.sole.update!(dismissed_at: Time.current)
    b.update!(isbn: "9780441013593")
    a.update!(isbn: "9780441013593")

    2.times { described_class.call(a) }

    expect(user.books.count).to eq(2)
    expect(DuplicateCandidate.count).to eq(1)
  end

  it "upgrades an open candidate to a merge once a confident key appears" do
    a = book(title: "Dune", author: "Frank Herbert")
    b = book(title: "Dune", author: "Frank Herbert")
    described_class.call(b)
    a.update!(isbn: "9780441013593")
    b.update!(isbn: "9780441013593")

    described_class.call(b)

    expect(user.books.ids).to eq([ a.id ])
    expect(DuplicateCandidate.count).to eq(0)
  end

  it "never looks at another user's shelf" do
    create(:book, title: "Solaris", isbn: "9780156027601")
    mine = book(title: "Solaris", isbn: "9780156027601")

    described_class.call(mine)

    expect(Book.exists?(mine.id)).to be(true)
  end
end
