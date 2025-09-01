require 'sidekiq/web'

Rails.application.routes.draw do
  mount Sidekiq::Web => '/sidekiq'
  resources :products
  
  # Cart routes
  post '/cart/add_item', to: 'carts#add_item'
  delete '/cart/:product_id', to: 'carts#remove_item'
  post '/cart', to: 'carts#create'
  get '/cart', to: 'carts#show'
  
  get "up" => "rails/health#show", as: :rails_health_check

  root "rails/health#show"
end
