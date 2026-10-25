require "rails_helper"

RSpec.describe "Public files" do
  let(:asset) { "assets/spec-#{SecureRandom.hex(4)}.js" }

  around do |example|
    created = [ "index.html", asset ].map { Rails.public_path.join(it) }.reject(&:exist?)
    created.each do |path|
      path.dirname.mkpath
      path.write("<div id=root></div>")
    end
    example.run
  ensure
    created&.each { it.delete if it.exist? }
  end

  it "makes the browser revalidate the app shell and other public files" do
    get "/", headers: { "Accept" => "text/html" }
    expect(response).to have_http_status(:ok)
    expect(response.headers["Cache-Control"]).to eq("no-cache")

    get "/robots.txt"
    expect(response.headers["Cache-Control"]).to eq("no-cache")
  end

  it "caches fingerprinted assets for a year" do
    get "/#{asset}"

    expect(response).to have_http_status(:ok)
    expect(response.headers["Cache-Control"]).to eq("public, max-age=#{1.year.to_i}, immutable")
  end
end
