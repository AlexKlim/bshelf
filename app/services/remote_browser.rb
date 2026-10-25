# Wiring for the browser sessions behind "Sync Kindle" and the Litres captcha.
#
# A collector is any object with:
#   steps                       -> step keys shown while collecting, e.g. %w[library highlights]
#   logged_in?(session)         -> polled every tick while the person signs in
#   collect(session) { |step| } -> { books:, highlights: }; yields each finished step key
# Both may raise ProviderRefused (the store blocked the sign in) or PageChanged.
# session.websocket_url is the CDP endpoint of the Steel browser.
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

  # Collecting runs inside this worker process, so a deploy stopping it ends those sessions.
  # Live sessions only wait on ticks stored in Postgres and carry on in the new process.
  def self.interrupt_running!
    RemoteBrowserSession.where(id: running.to_a, status: "collecting")
      .find_each { it.finish!(interruption: "deploy_interrupted") }
  end
end
