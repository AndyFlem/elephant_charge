Rails.application.routes.draw do

  get 'charges/index'
  root 'charges#index'

  resources :cars
  resources :teams
  resources :photos, only: [:show]

  resources :charges do
    resources :photos
    member do
      patch 'photosupdate', to: 'photos#update_all'
      post 'uploadkml'
      post 'uploadmap'
      get 'stops'
      get 'entriesbulk'
      patch 'entriesbulk', to: 'charges#entriesbulkpost'
      get 'grants'
      patch 'grants', to: 'charges#grantspost'
      delete 'grant/:grant_id', to:'charges#grantdestroy'
      get 'charge_sponsors'
      patch 'charge_sponsors', to: 'charges#charge_sponsorspost'
      delete 'charge_sponsor/:charge_sponsor_id', to:'charges#charge_sponsordestroy'
      patch 'legstsetse', to: 'charges#legstsetse'
      get 'kml'
      get 'result'
      post 'clear_results'
      post 'process_results'
      post 'recalc_distances'
      post 'generate_xlsx'
      post 'generate_kml'
    end
    resources :guards
    resources :entries do
      resources :photos
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
        post 'uploadphoto'
      end
    end
    resources :legs
  end

  resources :sponsors do
    member do
      post 'uploadlogo'
    end
  end

  resources :checkins

  resources :beneficiaries do
    member do
      post 'uploadlogo'
    end
  end
end
