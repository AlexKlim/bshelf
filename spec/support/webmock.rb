require "webmock/rspec"

WebMock.disable_net_connect!(allow_localhost: true)

module CatalogStubs
  def catalog_fixture(name) = Rails.root.join("spec/fixtures/catalog", name).read

  def stub_open_library(fixture, **query)
    stub_request(:get, "https://openlibrary.org/search.json").with(query: hash_including(query.transform_keys(&:to_s)))
      .to_return(status: 200, body: catalog_fixture(fixture), headers: { "Content-Type" => "application/json" })
  end

  def stub_litres(fixture = nil, status: 200)
    stub_request(:get, %r{\Ahttps://api\.litres\.ru/foundation/api/search})
      .to_return(status:, body: fixture ? catalog_fixture(fixture) : "", headers: { "Content-Type" => "application/json" })
  end

  def stub_google(fixture = nil, status: 200, headers: {})
    body = fixture ? catalog_fixture(fixture) : ""
    stub_request(:get, %r{\Ahttps://www\.googleapis\.com/books/v1/volumes})
      .to_return(status:, body:, headers: { "Content-Type" => "application/json" }.merge(headers))
  end
end

RSpec.configure do |config|
  config.include CatalogStubs
  # Litres sits behind DDoS-Guard, so specs see the refusal unless they stub an answer.
  config.before { stub_litres(status: 403) }
end
