Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  devise_for :users, skip: [ :sessions, :registrations ]

  devise_for :users,
    controllers: {
      sessions: "users/sessions",
      registrations: "users/registrations"
    }

  devise_scope :user do
    post   "/login",  to: "users/sessions#create"
    delete "/logout", to: "users/sessions#destroy"
    post   "/signup", to: "users/registrations#create"
  end

  scope :api do
    get "/me", to: "me#show"
    patch "/me", to: "me#update"
  end
end
