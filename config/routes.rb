Rails.application.routes.draw do
  get 'up' => 'rails/health#show', as: :rails_health_check

  devise_for :users, skip: %i[sessions registrations]

  devise_for :users,
             controllers: {
               sessions: 'users/sessions',
               registrations: 'users/registrations'
             }

  devise_scope :user do
    post   '/login',  to: 'users/sessions#create'
    delete '/logout', to: 'users/sessions#destroy'
    post   '/signup', to: 'users/registrations#create'
  end

  scope :api do
    get '/me', to: 'me#show'
    patch '/me', to: 'me#update'
    get '/dashboard', to: 'dashboard#show'

    resources :groups, only: %i[show index create update] do
      resources :expenses, only: %i[index create]
      resources :invites, only: [:create], controller: 'invites'
    end

    resources :users, only: [:index]
    
    # Invite routes
    get '/invites/personal', to: 'invites#personal'
    get '/invites/:token', to: 'invites#show'
    post '/invites/:token/accept', to: 'invites#accept'
  end

  # Avatar endpoint (outside API scope, no auth required for public avatars)
  get '/avatars/:id', to: 'avatars#show', as: :avatar
end
