# frozen_string_literal: true

class Hyrax::HomepageController < ApplicationController
  # Adds Hydra behaviors into the application controller
  include Blacklight::SearchContext
  include Blacklight::AccessControls::Catalog

  class_attribute :presenter_class
  self.presenter_class = Hyrax::HomepagePresenter
  layout 'homepage'
  helper Hyrax::ContentBlockHelper

  def index
    @presenter = presenter_class.new(current_ability, collections)
    @marketing_text = ContentBlock.for(:marketing)
    @announcement_text = ContentBlock.for(:announcement)
    recent
    @homepage_props = HomepageSerializer.new(
      view_context: view_context,
      recent_documents: @recent_documents,
      collections: @presenter.collections
    ).as_json
  end

  private

  # Return 5 collections
  def collections(rows: 5)
    Hyrax::CollectionsService
      .new(self)
      .search_results { |builder| builder.rows(rows) }
  rescue Blacklight::Exceptions::ECONNREFUSED,
         Blacklight::Exceptions::InvalidRequest
    []
  end

  def recent
    # grab any recent documents
    _, @recent_documents =
      search_service.search_results do |builder|
        builder.rows(4)
        builder.merge(sort: sort_field)
      end
  rescue Blacklight::Exceptions::ECONNREFUSED,
         Blacklight::Exceptions::InvalidRequest
    @recent_documents = []
  end

  def search_service
    Hyrax::SearchService.new(
      config: blacklight_config,
      user_params: {
        q: ''
      },
      scope: self,
      search_builder_class: search_builder_class
    )
  end

  def sort_field
    'date_uploaded_dtsi desc'
  end

  def search_builder_class
    Hyrax::HomepageSearchBuilder
  end
end
