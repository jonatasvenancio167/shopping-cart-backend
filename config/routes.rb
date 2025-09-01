require 'sidekiq/web'

Rails.application.routes.draw do
  mount Sidekiq::Web => '/sidekiq'
  resources :products
  
  # Cart routes
  get '/cart', to: 'carts#show'
  post '/cart', to: 'carts#create'
  post '/cart/add_item', to: 'carts#add_item'
  delete '/cart/:product_id', to: 'carts#remove_item'
  
  get "up" => "rails/health#show", as: :rails_health_check

  root "rails/health#show"
end
