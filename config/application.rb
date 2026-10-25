require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"

Bundler.require(*Rails.groups)

module Bshelf
  class Application < Rails::Application
    config.load_defaults 8.1
    config.autoload_lib(ignore: %w[assets tasks])
    config.api_only = true

    # Same-origin SPA authenticates with a devise cookie session, which API mode strips out.
    config.session_store :cookie_store, key: "_bshelf_session", same_site: :lax, expire_after: 30.days
    config.middleware.use ActionDispatch::Cookies
    config.middleware.use config.session_store, config.session_options

    config.active_job.queue_adapter = :solid_queue
    config.x.app_url = ENV.fetch("APP_URL", "http://localhost:5173")
  end
end
