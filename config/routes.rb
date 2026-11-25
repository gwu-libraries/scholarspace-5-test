require 'sidekiq/web'

Rails.application.routes.draw do
mount Bulkrax::Engine, at: '/'
  concern :iiif_search, BlacklightIiifSearch::Routes.new
  mount Riiif::Engine => 'images', :as => :riiif if Hyrax.config.iiif_image_server?

  mount Blacklight::Engine => '/'
  concern :searchable, Blacklight::Routes::Searchable.new
  concern :range_searchable, BlacklightRangeLimit::Routes::RangeSearchable.new

  resource :catalog,
           only: [:index],
           as: 'catalog',
           path: '/catalog',
           controller: 'catalog' do
    concerns :searchable
    concerns :range_searchable
  end
  devise_for :users, controllers: { omniauth_callbacks: 'users/omniauth_callbacks',
                                      sessions: 'users/sessions' }
  mount Hydra::RoleManagement::Engine => '/'
  mount Sidekiq::Web => '/sidekiq'
  mount Qa::Engine => '/authorities'
  mount BlacklightDynamicSitemap::Engine => '/'
  resources :welcome, only: 'index'
  get '/concern/:work_type/:id/deep_search', to: 'deep_search#deep_search'
  get '/up', to: proc { [200, { 'Content-Type' => 'text/plain' }, ['ok']] }
  mount Hyrax::Engine, at: '/'
  root 'hyrax/homepage#index'
  curation_concerns_basic_routes
  concern :exportable, Blacklight::Routes::Exportable.new
  get '/archival_document/:id', to: redirect('concern/archival_documents/%{id}')

  resources :solr_documents,
            only: [:show],
            path: '/catalog',
            controller: 'catalog' do
    concerns :exportable
    concerns :iiif_search
  end

  resources :bookmarks do
    concerns :exportable

    collection { delete 'clear' }
  end
  Hyrax::Engine.routes.draw do
    # Redirects non-privileged users to the application homepage
    authenticate :user, lambda { |u| !u.admin? && !u.contentadmin?} do
      namespace :dashboard do
        match '(*any)', to: redirect('/'), via: [:get, :post]
      end
    end
  end
  get '*alias_path', to: 'hyrax/redirects#show',
                     constraints: ->(_req) { Hyrax.config.redirects_active? },
                     format: false
end
