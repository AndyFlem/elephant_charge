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
      patch 'legstsetse', to: 'charges#legstsetse'
      get 'kml'
    end
    resources :guards
    resources :entries do
      member do
        post 'import'
        post 'process_clean'
        post 'guess_checkins'
        post 'process_result'
        post 'clear_result'
        post 'clear_clean'

        get 'kml'
        get 'geojson'
      end
    end
    resources :legs
  end

  resources :guard_sponsors

  resources :checkins
end
