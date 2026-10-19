# frozen_string_literal: true

# Shared behavior for all Scholarspace work controllers.
# Provides common setup: Hyrax integration, custom IIIF manifest builder, and work show presenter.
module WorksControllerBehavior
  extend ActiveSupport::Concern

  included do
    include Hyrax::WorksControllerBehavior
    include Hyrax::BreadcrumbsForWorks

    self.iiif_manifest_builder = IiifBuilders::ManifestBuilder
    self.show_presenter = WorkShowPresenter
    self.work_form_service = Hyrax::FormFactory.new

    def manifest
      headers['Access-Control-Allow-Origin'] = '*'

      json = iiif_manifest_builder.manifest_for(
        presenter: iiif_manifest_presenter,
        viewer: params[:viewer]
      )

      respond_to do |wants|
        wants.any { render json: json }
      end
    end
  end
end
