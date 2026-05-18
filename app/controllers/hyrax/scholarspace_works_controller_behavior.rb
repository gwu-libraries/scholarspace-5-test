# frozen_string_literal: true

module Hyrax
  # Shared behavior for all Scholarspace work controllers.
  # Provides common setup: Hyrax integration, custom IIIF manifest builder, and Scholarspace work show presenter.
  module ScholarspaceWorksControllerBehavior
    extend ActiveSupport::Concern

    included do
      include Hyrax::WorksControllerBehavior
      include Hyrax::BreadcrumbsForWorks

      self.iiif_manifest_builder = Hyrax::ScholarspaceIiifManifestBuilder
      self.show_presenter = Hyrax::ScholarspaceWorkShowPresenter
      self.work_form_service = Hyrax::FormFactory.new
    end
  end
end
