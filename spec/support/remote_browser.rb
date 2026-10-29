module RemoteBrowserHelpers
  def steel = RemoteBrowser.steel

  def collector = RemoteBrowser.collectors.fetch("kindle")

  def live_session(user, purpose: "kindle")
    user.remote_browser_sessions.create!(purpose:, status: "live", steel_session_id: SecureRandom.uuid,
      viewer_path: "v1/sessions/debug", expires_at: RemoteBrowserSession::LOGIN_TIME.from_now)
  end
end

RSpec.configure do |config|
  config.include RemoteBrowserHelpers
  config.around do |example|
    saved = %i[steel collectors max_sessions disabled].to_h { [ it, RemoteBrowser.public_send(it) ] }
    RemoteBrowser.steel = FakeSteelSession.new
    RemoteBrowser.collectors = { "kindle" => FakeCollector.new(login_delay: 0), "litres" => FakeCollector.new(login_delay: 0), "storytel" => FakeCollector.new(login_delay: 0) }
    RemoteBrowser.max_sessions = 1
    RemoteBrowser.disabled = false
    example.run
  ensure
    saved.each { |key, value| RemoteBrowser.public_send(:"#{key}=", value) }
    RemoteBrowser.running.clear
  end
end
