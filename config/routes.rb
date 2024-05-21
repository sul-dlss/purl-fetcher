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

  scope 'v1' do
    # We don't need all of the activestorage routes, just this one:
    put  '/disk/:encoded_token' => 'active_storage/disk#update', as: :update_rails_disk_service
  end

  scope 'v1', module: :v1 do
    resources :direct_uploads, only: :create, as: :rails_direct_upload
    resources :released, only: :update, param: :druid
    resource :mods, only: :create
    resources :resources, only: :create
  end
end
