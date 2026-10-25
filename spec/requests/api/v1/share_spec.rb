require "rails_helper"

RSpec.describe "Share" do
  let(:user) { create(:user) }
  let(:token) { ApiToken.issue!(user:, name: "iPhone").last }
  let(:hops) { {} }

  before do
    allow(LinkResolver).to receive(:lookup).and_return([ "93.184.216.34" ])
    allow(LinkResolver).to receive(:http_get) { |uri, _ip, _timeout| hops.fetch(uri.to_s) { [ 200, nil ] } }
  end

  def share(locale: nil, **body)
    headers = bearer(token)
    headers["Accept-Language"] = locale if locale
    post "/api/v1/share", params: body, headers:, as: :json
  end

  def edition_on_shelf(book, format:, store:, external_id:, status:, finished_at: nil)
    edition = create(:edition, book:, format:, store:, external_id:)
    create(:reading, edition:, status:, status_source: "manual", finished_at:)
  end

  it "needs a token" do
    post "/api/v1/share", params: { url: "https://a.co/d/1" }, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it "rejects an empty share" do
    share(url: "", text: " ")

    expect(response).to have_http_status(:bad_request)
    expect(error_codes).to eq([ "blank" ])
  end

  it "answers listened with the month for a Litres link on the shelf" do
    book = create(:book, user:, title: "Солярис", author: "Станислав Лем")
    edition_on_shelf(book, format: "audio", store: "litres", external_id: "6450429", status: "done",
      finished_at: Time.zone.local(2024, 3, 10))

    share(url: "https://www.litres.ru/audiobook/stanislav-lem/solyaris-6450429/")
    expect(json["answer"]).to eq("kind" => "listened", "book_id" => book.uuid)
    expect(json["message"]).to eq("Listened · Mar 2024")
    expect(json["link"]).to eq("store" => "litres", "external_id" => "6450429")

    share(url: "https://www.litres.ru/audiobook/stanislav-lem/solyaris-6450429/", locale: "ru-RU,ru;q=0.9")
    expect(json["message"]).to eq("Слушали · март 2024")
  end

  it "answers read with the year only, in both languages" do
    book = create(:book, user:, title: "Solaris")
    edition_on_shelf(book, format: "ebook", store: "amazon", external_id: "B0B7QSV2RK", status: "done",
      finished_at: Time.zone.local(2023, 5, 1))

    share(url: "https://www.amazon.com/dp/B0B7QSV2RK")
    expect(json["message"]).to eq("Read · 2023")

    share(url: "https://www.amazon.com/dp/B0B7QSV2RK", locale: "ru")
    expect(json["message"]).to eq("Читали · 2023")
  end

  it "picks the language from the first supported Accept-Language tag, else English" do
    create(:book, user:, title: "Solaris", status: "want")

    share(text: "Solaris", locale: "de-RU, en;q=0.8")
    expect(json["message"]).to start_with("In Want since ")

    share(text: "Solaris", locale: "de-DE, ru;q=0.8")
    expect(json["message"]).to start_with("В Хочу с ")

    share(text: "Solaris", locale: "fr-CA")
    expect(json["message"]).to start_with("In Want since ")
  end

  it "answers read and listened with both years through a short Amazon link" do
    book = create(:book, user:, title: "Solaris")
    edition_on_shelf(book, format: "ebook", store: "amazon", external_id: "B0B7QSV2RK", status: "done",
      finished_at: Time.zone.local(2023, 5, 1))
    edition_on_shelf(book, format: "audio", store: "litres", external_id: "1", status: "done",
      finished_at: Time.zone.local(2024, 1, 1))
    hops["https://a.co/d/3xYz9Q1"] = [ 301, "https://www.amazon.com/dp/B0B7QSV2RK" ]

    share(text: "Solaris by Stanislaw Lem https://a.co/d/3xYz9Q1")

    expect(json["answer"]["kind"]).to eq("read_and_listened")
    expect(json["message"]).to eq("Read and listened · 2023, 2024")

    share(text: "Solaris by Stanislaw Lem https://a.co/d/3xYz9Q1", locale: "ru")
    expect(json["message"]).to eq("Читали и слушали · 2023, 2024")
  end

  it "answers want with the month it was added, in Russian" do
    travel_to Time.zone.local(2025, 5, 20) do
      create(:book, user:, title: "Эдем", status: "want")
    end

    share(text: "Эдем - Станислав Лем | Литрес", locale: "ru")

    expect(json["answer"]["kind"]).to eq("want")
    expect(json["message"]).to eq("В Хочу с мая 2025")
  end

  it "matches the title from an Amazon page title when the link is not on the shelf" do
    book = create(:book, user:, title: "Solaris", status: "in_progress", format: "audio")
    create(:book, user:, title: "Eden", author: "Stanislaw Lem", status: "done")

    share(url: "https://www.amazon.com/dp/0156027607", text: "Amazon.com: Solaris eBook : Lem, Stanislaw: Kindle Store")

    expect(json["answer"]).to eq("kind" => "in_progress", "book_id" => book.uuid)
    expect(json["message"]).to eq("Listening")
  end

  it "splits a Litres page title on a long dash" do
    book = create(:book, user:, title: "Солярис", status: "owned")

    share(text: "Солярис \u2014 Станислав Лем, слушать онлайн аудиокнигу")

    expect(json["answer"]).to eq("kind" => "owned", "book_id" => book.uuid)
  end

  it "matches a title or original title regardless of punctuation and accents" do
    book = create(:book, user:, title: "Пикник на обочине", original_title: "Piknik na obochine", status: "owned")

    share(text: "Пикник на обочине! | Литрес")
    expect(json["answer"]).to eq("kind" => "owned", "book_id" => book.uuid)

    share(text: "Píknik na obochine: a novel")
    expect(json["answer"]).to eq("kind" => "owned", "book_id" => book.uuid)
  end

  it "looks every text segment up in one query" do
    book = create(:book, user:, title: "The Cyberiad: Fables for the Cybernetic Age", status: "want")
    likes = 0
    counter = ->(*, payload) { likes += 1 if payload[:sql].include?("ILIKE") }

    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      share(text: "Stanislaw Lem | Fables | Cyberiad, illustrated")
    end

    expect(json["answer"]).to eq("kind" => "want", "book_id" => book.uuid)
    expect(json["query"]).to eq("Fables")
    expect(likes).to eq(1)
  end

  it "does not answer for another book by the same author" do
    create(:book, user:, title: "Eden", author: "Stanislaw Lem", status: "done")

    share(text: "Stanislaw Lem - Solaris")

    expect(json["answer"]["kind"]).to eq("not_found")
  end

  it "lists similar books" do
    create(:book, user:, title: "Children of Dune")
    create(:book, user:, title: "Dune Messiah")

    share(text: "Dune", locale: "ru")
    expect(json["answer"]).to eq("kind" => "similar", "count" => 2)
    expect(json["message"]).to eq("Похожие: 2 книги")
    expect(json["books"].pluck("title")).to contain_exactly("Children of Dune", "Dune Messiah")
  end

  it "answers not on the shelf with a suggestion for quick add" do
    share(url: "https://www.amazon.com/dp/0156027607", text: "Solaris: Stanislaw Lem: 9780156027601: Amazon.com: Books")

    expect(json["answer"]).to eq("kind" => "not_found")
    expect(json["message"]).to eq("Not on the shelf")
    expect(json["suggestion"]).to eq("title" => "Solaris", "author" => "Stanislaw Lem",
      "store" => "amazon", "external_id" => "0156027607")
  end

  it "never matches another user's books" do
    other = create(:book, title: "Solaris")
    create(:edition, book: other, store: "litres", external_id: "6450429")

    share(url: "https://www.litres.ru/book/x/solaris-6450429/", text: "Solaris")

    expect(json["answer"]["kind"]).to eq("not_found")
  end

  it "falls back to the text when the link redirects to a private address" do
    book = create(:book, user:, title: "Solaris", status: "owned")
    hops["https://a.co/d/1"] = [ 302, "http://10.0.0.1/admin" ]

    share(text: "Solaris https://a.co/d/1")

    expect(LinkResolver).to have_received(:http_get).once
    expect(json["answer"]).to eq("kind" => "owned", "book_id" => book.uuid)
    expect(json["link"]).to be_nil
  end

  it "says the book is not recognized when there is nothing to match" do
    share(url: "http://169.254.169.254/latest/meta-data/")

    expect(response).to have_http_status(:ok)
    expect(json["answer"]).to eq("kind" => "unrecognized")
    expect(json["message"]).to eq("Could not recognize the book")
    expect(LinkResolver).not_to have_received(:lookup)
  end

  it "answers from the text within 2 seconds when the short link hangs" do
    book = create(:book, user:, title: "Solaris", status: "owned")
    allow(LinkResolver).to receive(:http_get) { sleep 5 }

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    share(text: "Solaris https://a.co/d/1")

    expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 2
    expect(json["answer"]).to eq("kind" => "owned", "book_id" => book.uuid)
    expect(json["link"]).to be_nil
  end

  it "keeps p95 under 2 seconds" do
    create_list(:book, 30, user:, status: "done")
    book = create(:book, user:, title: "Solaris")
    edition_on_shelf(book, format: "ebook", store: "amazon", external_id: "0156027607", status: "done")
    hops["https://a.co/d/1"] = [ 301, "https://www.amazon.com/dp/0156027607" ]

    durations = Array.new(20) do |i|
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      i.even? ? share(text: "Solaris https://a.co/d/1") : share(text: "Something else entirely")
      expect(response).to have_http_status(:ok)
      Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    end

    expect(durations.sort[(durations.size * 0.95).ceil - 1]).to be < 2
  end

  describe "quick add" do
    def add(**body) = post "/api/v1/share/add", params: body, headers: bearer(token), as: :json

    it "adds the shared book with its store id in one request" do
      add(title: "Solaris", author: "Stanislaw Lem",
        edition: { format: "audio", status: "done", store: "litres", external_id: "6450429" })

      expect(response).to have_http_status(:created)
      expect(json["message"]).to eq("Added · Listened")
      expect(json["book"]["editions"].first).to include("format" => "audio", "status" => "done",
        "store" => "litres", "source" => "share")
      expect(user.editions.find_by(store: "litres", external_id: "6450429")).to be_present
    end

    it "defaults to want and translates the confirmation" do
      post "/api/v1/share/add", params: { title: "Eden", locale: "ru" }, headers: bearer(token), as: :json

      expect(response).to have_http_status(:created)
      expect(json["message"]).to eq("Добавлено · Хочу")
    end

    it "refuses a book already on the shelf by store id or title" do
      add(title: "Solaris", edition: { store: "amazon", external_id: "0156027607" })
      add(title: "Another title", edition: { store: "amazon", external_id: "0156027607" })
      expect(response).to have_http_status(:conflict)
      expect(json["existing"]["title"]).to eq("Solaris")

      add(title: " solaris ")
      expect(response).to have_http_status(:conflict)
    end

    it "answers 409 with the book that won a race for the same store id" do
      winner = create(:book, user:, title: "Solaris")
      allow(AddBook).to receive(:call).and_wrap_original do |original, **args|
        create(:edition, book: winner, store: "amazon", external_id: "0156027607")
        original.call(**args)
      end

      add(title: "Solaris (Kindle)", edition: { store: "amazon", external_id: "0156027607" })

      expect(response).to have_http_status(:conflict)
      expect(json["existing"]["id"]).to eq(winner.uuid)
      expect(user.books.count).to eq(1)
    end

    it "matches an existing store id only together with its store" do
      create(:edition, book: create(:book, user:, title: "Solaris"), store: "amazon", external_id: "6450429")

      add(title: "Eden", edition: { external_id: "6450429" })

      expect(response).to have_http_status(:created)
    end

    it "validates status, format and store" do
      add(title: "Solaris", edition: { status: "loved" })
      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]).to eq([ { "field" => "status", "code" => "inclusion" } ])

      add(title: "Solaris", edition: { store: "ozon", external_id: "1" })
      expect(json["errors"]).to eq([ { "field" => "store", "code" => "inclusion" } ])

      add(edition: { status: "want" })
      expect(response).to have_http_status(:bad_request)

      add(title: "Solaris", edition: { status: "done", finished_at: "2024-02-30" })
      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]).to eq([ { "code" => "invalid", "field" => "finished_at" } ])
    end
  end
end
