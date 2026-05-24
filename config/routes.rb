Helios::Videos::Engine.routes.draw do
  namespace :admin do
    resources :videos, only: [:show, :update]
  end
end
