# frozen_string_literal: true

Bundler.ui.info '[Scholarspace] Adding global rubygems source.'
source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

gem 'activerecord-nulldb-adapter', '~> 1.1'
gem 'blacklight-access_controls'
gem 'blacklight_iiif_search'
gem 'bootsnap', '>= 1.1.0', require: false
gem 'bootstrap', '~> 4.0'
gem 'coffee-rails', '~> 4.2'
gem 'dalli'
gem 'derivative-rodeo'
gem 'devise'
gem 'devise-guests', '~> 0.8'
gem 'factory_bot_rails'
gem 'hydra-access-controls'
gem 'hydra-role-management'
gem 'hyrax', git: 'https://github.com/samvera/hyrax', branch: 'main'
gem 'jbuilder', '~> 2.5'
gem 'jquery-rails'
gem 'pg', '~> 1.3'
gem 'puma'
gem 'rails', '~> 7.2', '< 8.0'
gem 'riiif', '~> 2.1'
gem 'rsolr', '>= 1.0', '< 3'
gem 'rtesseract'
gem 'sidekiq', '~> 6.4'
gem 'turbolinks', '~> 5'
gem 'twitter-typeahead-rails', '0.11.1.pre.corejavascript'
gem 'tzinfo-data', platforms: %i[windows jruby]
gem 'uglifier', '>= 1.3.0'
gem 'whispercpp'

# gem "bulkrax"

group :development do
  gem 'better_errors' # add command line in browser when errors
  gem 'binding_of_caller' # deeper stack trace used by better errors
  gem 'rails_live_reload' # live reloading in development

  gem 'rubocop', require: false
  gem 'rubocop-capybara'
  gem 'rubocop-factory_bot'
  gem 'rubocop-rails'
  gem 'rubocop-rspec'
  gem 'rubocop-rspec_rails'
  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem 'web-console', '>= 3.3.0'
end

group :development, :test do
  gem 'awesome_print'
  gem 'capybara'
  gem 'database_cleaner'
  gem 'debug', '>= 1.0.0'
  gem 'faker'
  gem 'launchy'
  gem 'orderly'
  gem 'prettier_print'
  gem 'pry'
  gem 'pry-doc'
  gem 'pry-rails'
  gem 'pry-rescue'
  gem 'rspec-rails'
  gem 'shoulda-matchers'
  gem 'simplecov'
  gem 'syntax_tree'
  gem 'syntax_tree-haml'
  gem 'syntax_tree-rbs'
  gem 'vcr'
  gem 'webmock'
end
