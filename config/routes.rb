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

      resources :shelves, only: %i[index show], path: "shelf"
      resource :search, only: :show
      resources :books, only: %i[show create update destroy] do
        post :merge, on: :member
        resources :notes, only: %i[index create update destroy], shallow: true
        resources :highlights, only: :index
      end
      resources :editions, only: :update
      resources :merges, only: :destroy
      resource :stats, only: :show
      resources :sources, only: :index

      resource :share, only: :create do
        post :add
      end
      resources :remote_browser_sessions, only: %i[create show destroy] do
        member do
          post :viewer
          get "view(/*path)", action: :view, as: :view, format: false
        end
      end
    end
  end

  get "*path", to: "fallback#index", constraints: ->(req) {
    req.format.html? && !req.path.start_with?("/api/")
  }
  root "fallback#index"
end
