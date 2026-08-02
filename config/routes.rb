Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  namespace :admin do
    root "dashboard#index"
    resources :specialties
    resources :focus_areas
    resources :practitioners do
      collection do
        patch  :bulk_publish
        patch  :bulk_unpublish
        delete :bulk_destroy
      end
      member do
        post :send_claim_invitation
      end
    end
  end

  get  "/list-your-practice", to: "public/registrations#new",    as: :new_registration
  post "/list-your-practice", to: "public/registrations#create", as: :registrations

  get "/practitioners/:slug",
      to: "public/practitioners#show",
      as: :public_practitioner,
      constraints: { slug: /[a-z0-9\-]+/ }

  get  "/claim/:token", to: "public/claims#show",   as: :claim,        constraints: { token: /[A-Za-z0-9_\-]+/ }
  post "/claim/:token", to: "public/claims#create", as: :submit_claim, constraints: { token: /[A-Za-z0-9_\-]+/ }

  scope "/dashboard", module: "practitioner", as: "practitioner" do
    root "dashboard#show", as: "root"
    resource  :profile,   only: [:edit, :update]
    resource  :settings,  only: [:show, :update]
    resource  :account,   only: [:destroy]
    resources :treatments
    resources :gallery_images, only: [:index, :create, :destroy] do
      collection do
        patch :reorder
      end
    end
    resource :specialty, only: [:edit, :update], controller: "specialty"
    patch "/publish"   => "profiles#publish",   as: "publish"
    patch "/unpublish" => "profiles#unpublish", as: "unpublish"
  end

  get "/email_changes/:token", to: "public/email_changes#show",
      as: :confirm_email_change,
      constraints: { token: /[A-Za-z0-9_\-]+/ }

  get "up" => "rails/health#show", as: :rails_health_check

  root "public/home#index"
end
