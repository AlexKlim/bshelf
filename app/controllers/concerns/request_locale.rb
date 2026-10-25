module RequestLocale
  extend ActiveSupport::Concern

  LOCALES = %w[en ru].freeze

  included { around_action :with_request_locale }

  private

  def with_request_locale(&)
    languages = request.headers["Accept-Language"].to_s.split(",").map { it.split(";").first.to_s.strip.split("-").first }
    requested = [ params[:locale], *languages ].compact.map(&:downcase)
    I18n.with_locale(requested.find { LOCALES.include?(it) } || "en", &)
  end
end
