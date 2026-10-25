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
    # The server-rendered OAuth consent form denies with _method=delete; api_only drops this middleware.
    config.middleware.use Rack::MethodOverride
    config.middleware.use ActionDispatch::Cookies
    config.middleware.use config.session_store, config.session_options

    # Vite fingerprints everything under /assets. index.html, sw.js and the manifest keep their names,
    # so they must be revalidated or a deploy never reaches an installed client.
    config.public_file_server.headers = { "cache-control" => "no-cache" }
    config.middleware.insert_before ActionDispatch::Static, Rack::Static, urls: [ "/assets" ],
      root: config.root.join("public").to_s, cascade: true,
      header_rules: [ [ :all, { "cache-control" => "public, max-age=#{1.year.to_i}, immutable" } ] ]

    # Railway's edge reaches the app from the shared address space, so its hops are proxies, not clients.
    config.action_dispatch.trusted_proxies = ActionDispatch::RemoteIp::TRUSTED_PROXIES + [ IPAddr.new("100.64.0.0/10") ]

    config.active_job.queue_adapter = :solid_queue
    config.x.app_url = ENV.fetch("APP_URL", "http://localhost:5173")
  end
end
