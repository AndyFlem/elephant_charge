Rails.application.routes.draw do

  get 'charges/index'
  root 'charges#index'

  resources :cars
  resources :teams

  resources :charges do
    member do
      post 'uploadkml'
      get 'stops'
      get 'entriesbulk'
      patch 'entriesbulk', to: 'charges#entriesbulkpost'
    end
    resources :guards
    resources :entries do
      member do
        post 'import'
        post 'process_clean'
        post 'guess_checkins'
        post 'process_result'
        post 'clear_result'

        get 'kml'
        get 'geojson'
      end
    end
  end

  resources :guard_sponsors

  resources :checkins
end
