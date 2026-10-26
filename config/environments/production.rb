require "active_support/core_ext/integer/time"

required = %w[APP_URL MAIL_FROM RESEND_API_KEY].select { ENV[it].blank? }
raise "Set #{required.join(", ")} to boot in production" if required.any?

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false

  config.assume_ssl = true
  config.force_ssl = true
  config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  config.log_tags = [ :request_id ]
  config.logger = ActiveSupport::TaggedLogging.logger(STDOUT)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
  config.silence_healthcheck_path = "/up"
  config.active_support.report_deprecations = false

  config.cache_store = :memory_store

  config.action_mailer.default_url_options = { host: URI(config.x.app_url).host }
  ActiveSupport.on_load(:action_mailer) { add_delivery_method :resend, ResendDelivery, api_key: ENV["RESEND_API_KEY"] }
  config.action_mailer.delivery_method = :resend

  config.i18n.fallbacks = true
  config.active_record.dump_schema_after_migration = false
  config.active_record.attributes_for_inspect = [ :id ]
end
