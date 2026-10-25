Rails.application.routes.draw do
  devise_for :users, skip: :all

  get "up" => "rails/health#show", as: :rails_health_check

  use_doorkeeper do
    controllers authorizations: "oauth/authorizations"
    skip_controllers :applications, :authorized_applications, :token_info
  end
  get ".well-known/oauth-protected-resource(/mcp)", to: "mcp#metadata"
  match "mcp", to: "mcp#handle", via: %i[get post delete]

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
      resources :assistants, only: %i[index destroy]

      resources :shelves, only: %i[index show], path: "shelf"
      resource :search, only: :show
      resources :books, only: %i[show create update destroy] do
        post :merge, on: :member
        post :editions, on: :member, action: :add_edition
        resources :notes, only: %i[index create update destroy], shallow: true
        resources :highlights, only: :index
      end
      resources :editions, only: :update
      resources :merges, only: :destroy
      resources :duplicates, only: %i[index destroy]
      resource :stats, only: :show
      resources :sources, only: :index
    end
  end

  get "*path", to: "fallback#index", constraints: ->(req) {
    req.format.html? && !req.path.start_with?("/api/")
  }
  root "fallback#index"
end
