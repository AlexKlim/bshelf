require "net/http"

class CatalogClient
  class Error < StandardError; end

  class RateLimited < Error
    attr_reader :retry_after

    def initialize(host, retry_after)
      @retry_after = retry_after
      super("#{host} answered 429")
    end
  end

  PROVIDERS = %i[open_library google].freeze
  COVER_HOSTS = /\A(books\.google\.com|books\.googleusercontent\.com|covers\.openlibrary\.org|
    ([a-z0-9-]+\.)*archive\.org|([a-z0-9-]+\.)*litres\.ru)\z/x
  MAX_COVER_BYTES = 5.megabytes
  OPEN_LIBRARY_LANGUAGES = {
    "rus" => "ru", "eng" => "en", "ger" => "de", "fre" => "fr", "spa" => "es", "ita" => "it", "pol" => "pl",
    "ukr" => "uk", "jpn" => "ja"
  }.freeze

  def search(provider, title: nil, author: nil, isbn: nil)
    query = isbn ? "isbn:#{isbn}" : "q:#{TextKey.title(title)}|#{TextKey.title(author)}"
    CatalogEntry.fetch("#{provider}:#{query}") { send(provider, title:, author:, isbn:) }
  end

  def cover(url, redirects: 3)
    uri = URI(url)
    return unless uri.is_a?(URI::HTTPS) && uri.host.match?(COVER_HOSTS)

    location = nil
    body = get(uri, accept: "image/*") do |response|
      case response
      when Net::HTTPRedirection then location = response["Location"]
      when Net::HTTPSuccess then read_cover(uri, response)
      end
    end
    return body unless location

    cover(URI.join(uri, location).to_s, redirects: redirects - 1) if redirects.positive?
  end

  private

  def google(title:, author:, isbn:)
    q = isbn ? "isbn:#{isbn}" : [ "intitle:#{title}", author.presence && "inauthor:#{author}" ].compact.join(" ")
    params = { q:, maxResults: 5, printType: "books", key: ENV["GOOGLE_BOOKS_API_KEY"].presence }.compact
    json = get_json("https://www.googleapis.com/books/v1/volumes?#{URI.encode_www_form(params)}")
    Array(json&.dig("items")).map do |item|
      info = item["volumeInfo"]
      ids = Array(info["industryIdentifiers"]).to_h { [ it["type"], it["identifier"] ] }
      {
        title: info["title"], authors: Array(info["authors"]), isbn: ids["ISBN_13"] || ids["ISBN_10"],
        year: info["publishedDate"].to_s[0, 4].to_i.nonzero?, language: info["language"],
        page_count: info["pageCount"].to_i.nonzero?, work_title: nil,
        cover_url: info.dig("imageLinks", "thumbnail")&.sub(/\Ahttp:/, "https:")&.sub("&edge=curl", "")
      }
    end
  end

  def open_library(title:, author:, isbn:)
    params = isbn ? { isbn: } : { title:, author: author.presence }.compact
    fields = "title,author_name,cover_i,first_publish_year,language,number_of_pages_median"
    json = get_json("https://openlibrary.org/search.json?#{URI.encode_www_form(params.merge(limit: 5, fields:))}")
    Array(json&.dig("docs")).map do |doc|
      languages = Array(doc["language"])
      {
        title: doc["title"], authors: Array(doc["author_name"]), isbn: nil, year: doc["first_publish_year"],
        language: (OPEN_LIBRARY_LANGUAGES[languages.first] if languages.one?),
        page_count: doc["number_of_pages_median"], work_title: doc["title"],
        cover_url: doc["cover_i"] && "https://covers.openlibrary.org/b/id/#{doc["cover_i"]}-L.jpg"
      }
    end
  end

  def get_json(url)
    response = get(URI(url), accept: "application/json")
    JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)
  end

  def read_cover(uri, response)
    too_large = Error.new("#{uri.host}: cover too large")
    raise too_large if response.content_length.to_i > MAX_COVER_BYTES

    body = +""
    response.read_body do |chunk|
      body << chunk
      raise too_large if body.bytesize > MAX_COVER_BYTES
    end
    body
  end

  def get(uri, accept:)
    headers = { "Accept" => accept, "User-Agent" => "BookShelf/1 (#{Rails.configuration.x.app_url})" }
    Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) do |http|
      http.request(Net::HTTP::Get.new(uri, headers)) do |response|
        case response
        when Net::HTTPSuccess, Net::HTTPRedirection, Net::HTTPNotFound
          return block_given? ? yield(response) : response.tap(&:body)
        when Net::HTTPTooManyRequests then raise RateLimited.new(uri.host, Integer(response["Retry-After"], exception: false))
        else raise Error, "#{uri.host} answered #{response.code}"
        end
      end
    end
  rescue Timeout::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError => e
    raise Error, "#{uri.host}: #{e.class}"
  end
end
