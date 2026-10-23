# frozen_string_literal: true

Rails.application.config.to_prepare do
  require_dependency Rails.root.join('app/controllers/hyrax/downloads_controller_decorator').to_s

  unless Hyrax::DownloadsController < Hyrax::DownloadsControllerDecorator
    Hyrax::DownloadsController.prepend Hyrax::DownloadsControllerDecorator
  end
end