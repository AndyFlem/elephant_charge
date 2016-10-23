Rails.application.routes.draw do

  get 'charges/index'
  root 'charges#index'

  resources :cars
  resources :teams

  resources :charges do
    member do
      post 'uploadkml'
      get 'stops'
    end
    resources :guards
    resources :entries do
      member do
        post 'import'
        post 'process_clean'
        post 'guess_checkins'
        post 'process_result'

        get 'kml'
        get 'geojson'
      end
    end
  end

  resources :guard_sponsors

end
