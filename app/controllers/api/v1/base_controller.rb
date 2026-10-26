module Api
  module V1
    class BaseController < ActionController::API
      include ActionController::Cookies
      include ActionController::RequestForgeryProtection
      include RequestLocale

      # ponytail: per-process counters; move to a shared cache store once Puma runs more than one worker.
      RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new

      # API mode does not pass config.action_controller to modules included later.
      self.allow_forgery_protection = Rails.configuration.action_controller.allow_forgery_protection != false
      # Bearer-token requests carry no cookies, so CSRF only applies to the cookie session.
      protect_from_forgery with: :exception, unless: :bearer_request?
      # Before: a halted or rejected request still hands the client a token. After: sign-in rotates it.
      prepend_before_action :set_csrf_cookie, unless: :bearer_request?
      after_action :set_csrf_cookie, unless: :bearer_request?
      before_action :authenticate!

      rescue_from ActiveRecord::RecordNotFound, with: -> { render_error(:not_found, status: :not_found) }
      rescue_from ActionController::InvalidAuthenticityToken,
        with: -> { render_error(:invalid_csrf, status: :forbidden) }
      rescue_from ActionController::ParameterMissing,
        with: ->(e) { render_error(:blank, field: e.param, status: :bad_request) }
      rescue_from ReadingDates::Invalid,
        with: ->(e) { render_error(:invalid, field: e.field, status: :unprocessable_content) }

      def self.limit_rate(to:, within:, only:, name: nil, by: -> { request.remote_ip })
        rate_limit to:, within:, only:, name:, by:, store: RATE_LIMIT_STORE,
          with: -> { render_error(:rate_limited, status: :too_many_requests) }
      end

      private

      def current_user
        bearer_request? ? api_token&.user : warden.user(:user)
      end

      def api_token
        return @api_token if defined?(@api_token)

        @api_token = ApiToken.authenticate(request.authorization.to_s.delete_prefix("Bearer "))
      end

      def bearer_request? = request.authorization.present?

      def authenticate!
        return render_error(:unauthorized, status: :unauthorized) unless current_user

        require_session! unless request.get? || request.head? || bearer_writes?
        remember_locale unless bearer_request?
      end

      def remember_locale
        current_user.update_column(:locale, I18n.locale.to_s) if current_user.locale != I18n.locale.to_s
      end

      def bearer_writes? = false

      def require_session!
        render_error(:session_required, status: :forbidden) if bearer_request?
      end

      def warden = request.env["warden"]

      def date_params(scope = params) = scope.slice(*ReadingDates::FIELDS).to_unsafe_h.symbolize_keys

      def set_csrf_cookie
        cookies["CSRF-TOKEN"] = { value: form_authenticity_token, same_site: :lax, secure: request.ssl? }
      end

      def render_error(code, status:, field: nil, **extra)
        render json: { errors: [ { code: code.to_s, field: field&.to_s }.compact ], **extra }, status:
      end

      def render_model_errors(record, status: :unprocessable_content)
        errors = record.errors.map { |e| { field: e.attribute.to_s, code: e.type.to_s } }
        render json: { errors: }, status:
      end
    end
  end
end
