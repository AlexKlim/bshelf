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

  def self.interrupt_running!
    RemoteBrowserSession.where(id: running.to_a, status: "collecting")
      .find_each { it.finish!(interruption: "deploy_interrupted") }
  end
end
