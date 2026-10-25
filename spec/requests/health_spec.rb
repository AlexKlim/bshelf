require "rails_helper"

RSpec.describe "Health and SPA fallback" do
  it "reports health on /up" do
    get "/up"
    expect(response).to have_http_status(:ok)
  end

  it "serves the built client for unknown html routes" do
    dir = Pathname(Dir.mktmpdir)
    dir.join("index.html").write("<div id=root></div>")
    allow(Rails).to receive(:public_path).and_return(dir)

    get "/shelf", headers: { "Accept" => "text/html" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("root")
  end

  it "does not route api paths to the client" do
    get "/api/v1/nope", headers: { "Accept" => "text/html" }
    expect(response).to have_http_status(:not_found)
  end
end
