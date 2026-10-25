Rails.application.config.to_prepare do
  RemoteBrowser.max_sessions = ENV.fetch("REMOTE_BROWSER_MAX_SESSIONS", 1).to_i
  RemoteBrowser.disabled = ENV["REMOTE_BROWSER_DISABLED"].present?

  if Rails.env.local?
    RemoteBrowser.steel = FakeSteelSession.new
    RemoteBrowser.collectors = { "kindle" => FakeCollector.new, "litres" => FakeCollector.new }
  elsif ENV["STEEL_URL"].present?
    RemoteBrowser.steel = SteelClient.new(ENV["STEEL_URL"])
  end
end

SolidQueue.on_worker_stop { RemoteBrowser.interrupt_running! }
