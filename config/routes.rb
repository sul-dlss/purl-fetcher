Rails.application.routes.draw do
  root 'v1/docs#stats'

  scope module: :v1, constraints: ApiConstraint.new(version: 1), defaults: { format: :json } do
    resource :docs, only: [] do
      get 'deletes'
      get 'changes'
    end

    resources :purls, only: [:destroy], param: :druid do
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
