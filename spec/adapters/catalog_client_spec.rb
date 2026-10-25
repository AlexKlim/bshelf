require "rails_helper"

RSpec.describe CatalogClient do
  let(:url) { "https://covers.openlibrary.org/b/id/1-L.jpg" }
  let(:client) { described_class.new }

  it "returns a cover within the size limit" do
    stub_request(:get, url).to_return(status: 200, body: "\xFF\xD8\xFFcover".b)

    expect(client.cover(url)).to eq("\xFF\xD8\xFFcover".b)
  end

  it "refuses a cover whose Content-Length is over the limit before reading it" do
    stub_request(:get, url).to_return(status: 200, body: "small",
      headers: { "Content-Length" => (described_class::MAX_COVER_BYTES + 1).to_s })

    expect { client.cover(url) }.to raise_error(CatalogClient::Error, /too large/)
  end

  it "stops reading a cover body once it passes the limit" do
    stub_request(:get, url).to_return(status: 200, body: "x" * (described_class::MAX_COVER_BYTES + 1))

    expect { client.cover(url) }.to raise_error(CatalogClient::Error, /too large/)
  end

  it "follows a redirect to another cover host" do
    archive = "https://archive.org/download/x/1-L.jpg"
    stub_request(:get, url).to_return(status: 302, headers: { "Location" => archive })
    stub_request(:get, archive).to_return(status: 200, body: "jpeg")

    expect(client.cover(url)).to eq("jpeg")
  end
end
