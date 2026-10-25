Rails.application.routes.draw do
  devise_for :users, skip: :all

  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      resource :session, only: %i[create destroy]
      resource :registration, only: :create
      resource :confirmation, only: :create do
        post :resend
      end
      resource :password, only: %i[create update]
      resource :profile, only: %i[show destroy], path: "me"
      resources :api_tokens, only: %i[index create destroy]
    end
  end

  get "*path", to: "fallback#index", constraints: ->(req) {
    req.format.html? && !req.path.start_with?("/api/")
  }
  root "fallback#index"
end
