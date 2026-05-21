# frozen_string_literal: true

# Shared behavior for all Scholarspace work controllers.
# Provides common setup: Hyrax integration, custom IIIF manifest builder, and work show presenter.
module WorksControllerBehavior
  extend ActiveSupport::Concern

  included do
    include Hyrax::WorksControllerBehavior
    include Hyrax::BreadcrumbsForWorks

    self.iiif_manifest_builder = IiifManifestBuilder
    self.show_presenter = WorkShowPresenter
    self.work_form_service = Hyrax::FormFactory.new
  end
end
