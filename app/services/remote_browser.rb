module RemoteBrowser
  class ProviderRefused < StandardError; end
  class PageChanged < StandardError; end
  class BrowserFailed < StandardError; end

  mattr_accessor :steel, :disabled
  mattr_accessor :collectors, default: {}
  mattr_accessor :max_sessions, default: 1
  mattr_reader :running, default: Concurrent::Set.new

  def self.available?(purpose) = !disabled && steel.present? && collectors.key?(purpose)

  def self.release(steel_session_id)
    steel.release(steel_session_id)
  rescue StandardError => e
    Rails.logger.warn({ event: "remote_browser.release_failed", steel_session_id:, error: e.class.name }.to_json)
  end

  def self.open(session, url, timeout:)
    connect(session, timeout:) do |browser|
      # A context of its own keeps the person's cookies in memory, off Steel's profile that the next person gets.
      context = browser.command("Target.createBrowserContext", disposeOnDetach: false)["browserContextId"]
      id = browser.command("Target.createTarget", url:, browserContextId: context)["targetId"]
      browser.command("Target.getTargets")["targetInfos"].each do |info|
        browser.command("Target.closeTarget", targetId: info["targetId"]) if info["type"] == "page" && info["targetId"] != id
      end
      session.update!(target_id: id)
    end
  end

  def self.browse(session, timeout:)
    connect(session, timeout:) { yield tab(it, session.target_id) }
  end

  def self.connect(session, timeout:)
    steel.cdp(session.websocket_url) do |ws_url|
      browser = Ferrum::Browser.new(ws_url:, timeout:)
      yield browser
    ensure
      browser&.quit
    end
  rescue Ferrum::Error => e
    raise BrowserFailed, e.class.name
  end

  def self.tab(browser, id)
    50.times do
      target = browser.contexts.find_by(target_id: id)&.find_target { it.id == id }
      return target.page if target&.session_id

      sleep 0.1
    end
    raise PageChanged
  end
  private_class_method :connect, :tab

  def self.interrupt_running!
    RemoteBrowserSession.where(id: running.to_a, status: "collecting")
      .find_each { it.finish!(interruption: "deploy_interrupted") }
  end
end
