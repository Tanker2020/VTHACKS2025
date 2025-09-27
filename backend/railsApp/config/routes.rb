require "sidekiq/web"

Rails.application.routes.draw do
  root "home#index"

  post "/graphql", to: "graphql#execute"

  
  # Mount Sidekiq Web UI for monitoring at /sidekiq, protected by basic auth in non-development envs.
  if Rails.env.development?
    # In dev: open access
    mount Sidekiq::Web => "/sidekiq"
    mount GraphiQL::Rails::Engine, at: "/graphiql", graphql_path: "/graphql"
  else
    # In prod/test: protect with basic auth
    Sidekiq::Web.use Rack::Auth::Basic do |username, password|
      # hardcoded demo credentials: user=test, pass=test
      ActiveSupport::SecurityUtils.secure_compare(username, "test") &
        ActiveSupport::SecurityUtils.secure_compare(password, "test")
    end
    mount Sidekiq::Web => "/sidekiq"
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
  
  # Catch-all for unmatched routes — return JSON 404
  match '*unmatched', to: 'errors#not_found', via: :all
end
