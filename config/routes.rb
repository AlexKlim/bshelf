Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  get "*path", to: "fallback#index", constraints: ->(req) {
    req.format.html? && !req.path.start_with?("/api/")
  }
  root "fallback#index"
end
