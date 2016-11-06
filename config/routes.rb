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
      get 'result'
      post 'clear_results'
      post 'process_results'
      post 'recalc_distances'
    end
    resources :guards
    resources :entries do
      resources :checkins
      member do
        post 'import'
        post 'process_clean'
        post 'guess_checkins'
        post 'process_result'
        post 'clear_result'
        post 'clear_clean'

        get 'kml'
        get 'geojson'
        get 'legsedit'
        patch 'legsedit', to: 'entries#legsedit_update'
      end
    end
    resources :legs
  end

  resources :guard_sponsors

  resources :checkins
end
