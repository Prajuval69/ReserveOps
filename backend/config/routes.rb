# frozen_string_literal: true

Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      get 'health', to: 'health#show'
      get 'dashboard', to: 'dashboard#show'
      get 'auth/csrf', to: 'auth#csrf'
      post 'auth/login', to: 'auth#login'
      post 'auth/logout', to: 'auth#logout'
      get 'auth/me', to: 'auth#me'
      get 'categories', to: 'catalog#categories'
      post 'categories', to: 'catalog#create_category'
      patch 'categories/:id', to: 'catalog#update_category'
      delete 'categories/:id', to: 'catalog#destroy_category'
      get 'locations', to: 'catalog#locations'
      post 'locations', to: 'catalog#create_location'
      patch 'locations/:id', to: 'catalog#update_location'
      delete 'locations/:id', to: 'catalog#destroy_location'
      get 'users', to: 'catalog#users'
      put 'manager-scopes/:user_id', to: 'catalog#assign_manager'
      resources :resources, only: %i[index show create update destroy] do
        member do
          get :availability
          get :blackouts
          post :blackouts, action: :create_blackout
        end
      end
      resources :bookings, only: %i[index show create] do
        member do
          patch :reschedule
          post :cancel
          post :approve
          post :reject
        end
      end
      get 'approvals', to: 'bookings#approvals'
      post 'waitlist', to: 'waitlist#create'
      get 'waitlist/mine', to: 'waitlist#mine'
      delete 'waitlist/:id', to: 'waitlist#destroy'
      resources :notifications, only: [:index] do
        post :read, on: :member
      end
      get 'analytics/overview', to: 'analytics#overview'
    end
  end
end
