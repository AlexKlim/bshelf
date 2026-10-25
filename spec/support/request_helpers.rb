module RequestHelpers
  def json = response.parsed_body

  def error_codes = json.fetch("errors").map { it["code"] }

  def sign_in_as(user, password: "password123")
    post "/api/v1/session", params: { email: user.email, password: }, as: :json
    expect(response).to have_http_status(:ok)
  end

  def bearer(raw) = { "Authorization" => "Bearer #{raw}" }
end

RSpec.configure do |config|
  config.include RequestHelpers, type: :request
  config.before(type: :request) { Api::V1::BaseController::RATE_LIMIT_STORE.clear }
end
