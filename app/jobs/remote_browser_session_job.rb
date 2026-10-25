# One tick of a browser session. While the person signs in, the job re-enqueues itself instead
# of sleeping, so it holds no worker thread and survives a deploy.
class RemoteBrowserSessionJob < ApplicationJob
  TICK = 2.seconds

  def perform(session)
    case session.status
    when "connecting" then connect(session)
    when "live" then watch(session)
    end
  rescue RemoteBrowser::ProviderRefused
    session.finish!(interruption: "provider_refused")
  rescue StandardError => e
    session.finish!(interruption: "browser_failed")
    raise unless e.is_a?(RemoteBrowser::PageChanged) || e.is_a?(RemoteBrowser::BrowserFailed)
  end

  private

  def connect(session)
    browser = RemoteBrowser.steel.create_session
    live = session.transition!(from: "connecting", to: "live", steel_session_id: browser.id,
      websocket_url: browser.websocket_url, viewer_path: browser.viewer_path,
      expires_at: RemoteBrowserSession::LOGIN_TIME.from_now)
    return RemoteBrowser.release(browser.id) unless live

    tick(session)
  end

  def watch(session)
    return session.finish!(interruption: "timeout", from: "live") if session.expires_at.past?

    collector = RemoteBrowser.collectors.fetch(session.purpose)
    collector.logged_in?(session) ? collect(session, collector) : tick(session)
  end

  def collect(session, collector)
    steps = collector.steps.map { { key: it, state: "pending" } }
    return unless session.transition!(from: "live", to: "collecting", steps:)

    RemoteBrowser.running << session.id
    result = collector.collect(session) { session.step_done!(it) }
    session.finish!(to: "done", result:, from: "collecting")
  ensure
    RemoteBrowser.running.delete(session.id)
  end

  def tick(session) = self.class.set(wait: TICK).perform_later(session)
end
