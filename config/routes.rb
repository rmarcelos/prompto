Rails.application.routes.draw do
  root 'sessions#new'

  resources :users do
    member do
      patch :avatar
      delete :avatar, action: :destroy_avatar
      patch :team_memberships
    end
  end

  resources :teams do
    resources :team_users, only: [:create, :update, :destroy], param: :user_id
  end

  get 'help', to: 'help#show'
  resource :help_draft, path: 'help/draft', only: [:update], controller: 'help_drafts' do
    post :publish
  end
  resources :help_blocks, path: 'help/blocks', only: [:create, :update, :destroy]

  get 'login', to: 'sessions#new'
  post 'login', to: 'sessions#create'
  delete 'logout', to: 'sessions#destroy'

  resources :prompts do
    resource :favorite, only: [:create, :destroy]
    resources :prompt_teams, only: [:destroy], param: :team_id
    resources :comments, only: :create do
      resource :vote, controller: 'comment_votes', only: [:create, :destroy]
    end
  end
  get 'home', to: redirect('/prompts')

end