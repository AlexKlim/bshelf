module RemoteBrowser
  class ProviderRefused < StandardError; end
  class PageChanged < StandardError; end
  class BrowserFailed < StandardError; end

  mattr_accessor :steel, :disabled
  mattr_accessor :collectors, default: {}
  mattr_accessor :max_sessions, default: 1
  mattr_reader :running, default: Concurrent::Set.new
  mattr_reader :guards, default: Concurrent::Map.new
  GUARDED = %w[live collecting].freeze
  NO_PASSKEYS = <<~JS.freeze
    (() => {
      const credentials = navigator.credentials
      if (!credentials) return
      const refuse = () => Promise.reject(new DOMException("Passkeys are not available in this browser", "NotAllowedError"))
      for (const name of ["get", "create"]) {
        const original = credentials[name].bind(credentials)
        credentials[name] = (options) => (options && options.publicKey ? refuse() : original(options))
      }
      if (window.PublicKeyCredential) {
        PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable = () => Promise.resolve(false)
        PublicKeyCredential.isConditionalMediationAvailable = () => Promise.resolve(false)
      }
    })()
  JS
  GUARD_WAIT = 10
  Guard = Data.define(:thread, :ready)

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
      id = browser.command("Target.createTarget", url: "about:blank", browserContextId: context)["targetId"]
      browser.command("Target.getTargets")["targetInfos"].each do |info|
        browser.command("Target.closeTarget", targetId: info["targetId"]) if info["type"] == "page" && info["targetId"] != id
      end
      session.update!(target_id: id)
      guard(session, timeout:).wait(GUARD_WAIT)
      tab(browser, id).go_to(url)
    end
  end

  def self.browse(session, timeout:)
    guard(session, timeout:).wait(GUARD_WAIT)
    connect(session, timeout:) { yield tab(it, session.target_id) }
  end

  def self.guard(session, timeout:)
    current = guards[session.id]
    return current.ready if current&.thread&.alive?

    # A passkey prompt opens a dialog headless Chrome never shows, and the page takes no input while it waits. A script
    # run before each page turns the prompt down at once. It lives only as long as the CDP session that added it, and
    # a virtual authenticator would not do either: any other session detaching from the tab switches it off.
    ready = Concurrent::Event.new
    thread = Thread.new do
      connect(session, timeout:) do |browser|
        page = tab(browser, session.target_id)
        page.command("Page.addScriptToEvaluateOnNewDocument", source: NO_PASSKEYS)
        ready.set
        sleep 2 while Rails.application.executor.wrap { RemoteBrowserSession.exists?(id: session.id, status: GUARDED) }
      end
    rescue StandardError => e
      Rails.logger.warn({ event: "remote_browser.guard_failed", session: session.uuid, error: e.class.name }.to_json)
    ensure
      ready.set
      guards.compute_if_present(session.id) { it.thread == Thread.current ? nil : it }
    end
    guards[session.id] = Guard.new(thread, ready)
    ready
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
  private_class_method :guard, :connect, :tab

  def self.interrupt_running!
    RemoteBrowserSession.where(id: running.to_a, status: "collecting")
      .find_each { it.finish!(interruption: "deploy_interrupted") }
  end
end
