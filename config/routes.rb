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
    delete '/me', to: 'me#destroy'
    get '/dashboard', to: 'dashboard#show'

    # Email verification routes
    post '/email_verifications/send_code', to: 'email_verifications#send_code'
    post '/email_verifications/verify_code', to: 'email_verifications#verify_code'
    get '/email_verifications/status', to: 'email_verifications#status'

    resources :groups, only: %i[show index create update] do
      resources :expenses, only: %i[index create]
      resources :invites, only: [:create], controller: 'invites'
      resources :settlements, only: %i[index create show]
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
