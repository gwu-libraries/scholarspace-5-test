# frozen_string_literal: true

Bundler.ui.info "[Scholarspace] Adding global rubygems source."
source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

gem "bootsnap", ">= 1.1.0", require: false
gem "bootstrap", "~> 4.0"
gem "coffee-rails", "~> 4.2"
gem "dalli"
gem "devise"
gem "devise-guests", "~> 0.8"

# Required because grpc and google-protobuf gem's binaries are not compatible with Alpine Linux.
# To install the package in Alpine: `apk add ruby-grpc`
# The pinned versions should match the version provided by the Alpine packages.

# Disabled due to dependency mismatches in Alpine packages (grpc 1.62.1 needs protobuf ~> 3.25)
# if RUBY_PLATFORM =~ /musl/
#   path '/usr/lib/ruby/gems/3.3.0' do
#     gem 'google-protobuf', '~> 3.24.4', force_ruby_platform: true
#     gem 'grpc', '~> 1.62.1', force_ruby_platform: true
#   end
# end

# gemspec name: 'hyrax', path: ENV.fetch('HYRAX_ENGINE_PATH', '..')
gem "hyrax"
gem "jbuilder", "~> 2.5"
gem "jquery-rails"
gem "pg", "~> 1.3"
gem "puma"
gem "rails", "~> 7.2", "< 8.0"
gem "riiif", "~> 2.1"
gem "rsolr", ">= 1.0", "< 3"
gem "sass-rails", "~> 6.0"
gem "sidekiq", "~> 7.3"
gem "turbolinks", "~> 5"
gem "twitter-typeahead-rails", "0.11.1.pre.corejavascript"
gem "tzinfo-data", platforms: %i[mingw mswin x64_mingw jruby]
gem "uglifier", ">= 1.3.0"
gem "activerecord-nulldb-adapter", "~> 1.1"
gem "rtesseract"

group :development do
  gem "better_errors" # add command line in browser when errors
  gem "binding_of_caller" # deeper stack trace used by better errors
  gem "rails_live_reload" # live reloading in development

  # Access an interactive console on exception pages or by calling 'console' anywhere in the code.
  gem "web-console", ">= 3.3.0"
end

group :development, :test do
  gem "factory_bot_rails"
  gem "debug", ">= 1.0.0"
  gem "pry-doc"
  gem "pry-rails"
  gem "pry-rescue"
  gem "capybara"
  gem "database_cleaner"
  gem "launchy"
  gem "orderly"
  gem "prettier_print"
  gem "pry"
  gem "awesome_print"
  gem "rspec-rails"
  gem "shoulda-matchers"
  gem "simplecov"
  gem "syntax_tree"
  gem "syntax_tree-haml"
  gem "syntax_tree-rbs"
  gem "vcr"
  gem "webmock"
  gem "faker"
end
