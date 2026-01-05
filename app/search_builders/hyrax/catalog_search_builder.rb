# frozen_string_literal: true

module Hyrax
  class CatalogSearchBuilder < ::SearchBuilder
    include Blacklight::Solr::SearchBuilderBehavior
    include Hydra::AccessControlsEnforcement
    include Hyrax::SearchFilters

  end
end
