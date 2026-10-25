FactoryBot.define do
  factory :book do
    user
    sequence(:title) { "Book #{it}" }
    author { "Author" }

    transient do
      format { "ebook" }
      status { nil }
      status_source { "manual" }
      started_at { nil }
      finished_at { nil }
    end

    after(:create) do |book, ev|
      next unless ev.status

      edition = create(:edition, book:, format: ev.format)
      create(:reading, edition:, status: ev.status, status_source: ev.status_source,
        started_at: ev.started_at, finished_at: ev.finished_at)
    end
  end

  factory :edition do
    book
    user { book.user }
    format { "ebook" }
    source { "manual" }
  end

  factory :reading do
    edition
    user { edition.user }
    status { "owned" }
    status_source { "purchase" }
  end

  factory :note do
    book
    user { book.user }
    body { "A thought" }
  end

  factory :highlight do
    book
    user { book.user }
    source { "kindle_browser" }
    sequence(:text) { "Quote #{it}" }
  end
end
