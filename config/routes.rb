Rails.application.routes.draw do
  root 'v1/docs#stats'

  scope module: :v1, constraints: ApiConstraint.new(version: 1), defaults: { format: :json } do
    resources :released, only: :show, param: :release_tag

    resources :purls, only: [:destroy, :show], param: :druid

    resources :collections, only: [], param: :druid  do
      member do
        get 'purls'
      end
    end
  end

  scope 'v1', module: :v1 do
    # backwards compatibility
    patch 'released/:druid', to: 'purls#release_tags'
    put 'released/:druid', to: 'purls#release_tags'

    resource :mods, only: :create

    # backwards-compatibility.
    post 'resources', to: 'purls#create'

    resources :purls, only: [:destroy, :show], param: :druid do
      member do
        put '/', to: 'purls#create'

        put 'release_tags'
        patch 'release_tags'
      end
    end
  end
end
