Helios::Videos::Engine.routes.draw do
  namespace :admin do
    resources :videos, only: [:update]
  end
end
