require "rails_helper"

RSpec.describe "Remote browser sessions" do
  let(:user) { create(:user) }

  def start(**body) = post "/api/v1/remote_browser_sessions", params: { purpose: "kindle", disclosure_accepted: true, **body }, as: :json

  def viewer_url(session)
    post "/api/v1/remote_browser_sessions/#{session.uuid}/viewer", as: :json
    expect(response).to have_http_status(:ok)
    json["url"]
  end

  context "when signed in" do
    before { sign_in_as(user) }

    it "starts a session after the disclosure and returns it again on reconnect" do
      start(disclosure_accepted: false)
      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]).to eq([ { "code" => "accepted", "field" => "disclosure_accepted" } ])

      start
      expect(response).to have_http_status(:created)
      expect(json["session"]).to include("purpose" => "kindle", "status" => "connecting", "queue_position" => nil,
        "steps" => [], "result" => nil, "interruption" => nil)
      id = json["session"]["id"]

      start
      expect(response).to have_http_status(:ok)
      expect(json["session"]["id"]).to eq(id)
      expect(AuditEvent.where(user:, action: "remote_browser_started").count).to eq(1)
    end

    it "shows the queue position when every browser is busy" do
      RemoteBrowserSession.start!(create(:user), "kindle")

      start

      expect(json["session"]).to include("status" => "queued", "queue_position" => 1)
    end

    it "shows the live timer and lets the person abort" do
      session = live_session(user)

      get "/api/v1/remote_browser_sessions/#{session.uuid}"
      expect(json["session"]["seconds_left"]).to be_within(2).of(300)

      delete "/api/v1/remote_browser_sessions/#{session.uuid}", as: :json
      expect(json["session"]).to include("status" => "interrupted", "interruption" => "aborted", "seconds_left" => nil)
      expect(steel.released).to eq([ session.steel_session_id ])
    end

    it "refuses unknown purposes and a disabled instance" do
      start(purpose: "audible")
      expect(json["errors"]).to eq([ { "code" => "inclusion", "field" => "purpose" } ])

      RemoteBrowser.disabled = true
      start
      expect(response).to have_http_status(:service_unavailable)
      expect(error_codes).to eq([ "unavailable" ])
    end

    it "hides other people's sessions" do
      other = live_session(create(:user))

      get "/api/v1/remote_browser_sessions/#{other.uuid}"
      expect(response).to have_http_status(:not_found)
      post "/api/v1/remote_browser_sessions/#{other.uuid}/viewer", as: :json
      expect(response).to have_http_status(:not_found)
    end

    it "gives a viewer only for a live session" do
      session = RemoteBrowserSession.start!(user, "kindle")

      post "/api/v1/remote_browser_sessions/#{session.uuid}/viewer", as: :json

      expect(response).to have_http_status(:conflict)
      expect(error_codes).to eq([ "not_live" ])
    end

    describe "live view proxy" do
      let(:session) { live_session(user) }

      it "trades a one-time token for a cookie that covers the page's subresources" do
        url = viewer_url(session)
        expect(url).to match(%r{\A/api/v1/remote_browser_sessions/#{session.uuid}/view/v1/sessions/debug\?token=\w+\z})

        get url
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Fake browser #{session.steel_session_id} at /v1/sessions/debug")
        expect(response.headers).to include("Cache-Control" => "no-store", "Content-Security-Policy" => "frame-ancestors 'self'")
        expect(Array(response.headers["Set-Cookie"]).find { it.start_with?("rb_view_") }).to include("path=/api/v1/remote_browser_sessions/#{session.uuid}/view", "httponly")

        get "/api/v1/remote_browser_sessions/#{session.uuid}/view/assets/app.js"
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("at /assets/app.js")

        get url
        expect(response).to have_http_status(:forbidden)
        expect(error_codes).to eq([ "invalid_token" ])
      end

      it "rejects requests without a token or cookie" do
        session
        get "/api/v1/remote_browser_sessions/#{session.uuid}/view/v1/sessions/debug"

        expect(response).to have_http_status(:forbidden)
      end

      it "rejects a token issued for another session" do
        other = live_session(create(:user))
        stolen = other.issue_viewer_token!
        mine = session

        get "/api/v1/remote_browser_sessions/#{mine.uuid}/view/x?token=#{stolen}"

        expect(response).to have_http_status(:forbidden)
      end

      it "rejects the owner's token in another account's hands" do
        url = viewer_url(session)
        sign_in_as(create(:user))

        get url

        expect(response).to have_http_status(:not_found)
        expect(session.reload.viewer_token_digest).to be_present
      end

      it "reconnects to the same session with a fresh token after the phone comes back" do
        get viewer_url(session)
        get viewer_url(session)

        expect(response).to have_http_status(:ok)
        expect(steel.released).to be_empty
      end

      it "stops serving once the session ends" do
        get viewer_url(session)
        session.finish!(interruption: "aborted")

        get "/api/v1/remote_browser_sessions/#{session.uuid}/view/assets/app.js"

        expect(response).to have_http_status(:forbidden)
      end

      it "stops serving when the sign-in time is over" do
        get viewer_url(session)

        travel(RemoteBrowserSession::LOGIN_TIME + 1.second) do
          get "/api/v1/remote_browser_sessions/#{session.uuid}/view/assets/app.js"
        end

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  it "is closed to API tokens" do
    raw = ApiToken.issue!(user:, name: "script").last

    post "/api/v1/remote_browser_sessions", params: { purpose: "kindle", disclosure_accepted: true },
      headers: bearer(raw), as: :json

    expect(response).to have_http_status(:forbidden)
    expect(error_codes).to eq([ "session_required" ])
  end
end
