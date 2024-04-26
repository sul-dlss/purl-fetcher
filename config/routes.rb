Rails.application.routes.draw do
  root 'v1/docs#stats'

  scope module: :v1, constraints: ApiConstraint.new(version: 1), defaults: { format: :json } do
    resources :released, only: :show

    resources :purls, only: [:destroy, :show], param: :druid do
      member do
        post '/', action: 'update'
      end
    end

    resources :collections, only: [], param: :druid  do
      member do
        get 'purls'
      end
    end
  end
end
