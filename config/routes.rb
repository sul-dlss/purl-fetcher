Rails.application.routes.draw do
  root 'v1/docs#stats'

  scope module: :v1, constraints: ApiConstraint.new(version: 1), defaults: { format: :json } do
    resources :released, only: :show
    resources :released, only: :update, param: :druid

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
    # We don't need all of the activestorage routes, just these:
    put  '/disk/:encoded_token' => 'active_storage/disk#update', as: :update_rails_disk_service
    post '/direct_uploads' => 'v1/direct_uploads#create', as: :rails_direct_upload
  end
end
