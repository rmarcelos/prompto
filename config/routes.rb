Rails.application.routes.draw do
  root 'users#home'

  devise_for :users, path: '', path_names: {
    sign_in: 'login',
    sign_out: 'logout'
  }

  # member routes → adding a extra action to a resource: users/12/avatar
  resources :users do
    member do
      patch :avatar
      delete :avatar, action: :destroy_avatar
      patch :team_memberships
    end
  end

  # nested resources → each team_users belongs to a team: teams/3/team_users/12
  resources :teams do
    resources :team_users, only: [:create, :update, :destroy], param: :user_id
  end

  get 'help', to: 'help#show'

  resources :prompts do
    resource :favorite, only: [:create, :destroy]
    resources :prompt_teams, only: [:destroy], param: :team_id
    resources :comments, only: :create do
      resource :vote, controller: 'comment_votes', only: [:create, :destroy]
    end
  end

  get 'home', to: 'users#home', as: :home
end
