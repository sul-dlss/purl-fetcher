Rails.application.routes.draw do
  root 'v1/docs#stats'

  scope module: :v1, constraints: ApiConstraint.new(version: 1) do
    resource :docs, :defaults => { :format => 'json' }, :only => [:get] do
      get 'deletes'
      get 'changes'
    end

    resources :purls, defaults: { format: :json }, only: [:index, :show, :destroy], param: :druid do
      member do
        post '/', action: 'update'
      end
    end

    resources :collections, defaults: { format: :json }, only: [:index, :show], param: :druid  do
      member do
        get 'purls'
      end
    end
  end
end
