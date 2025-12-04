# frozen_string_literal: true

module Hyrax
  class CatalogSearchBuilder < ::SearchBuilder
    include Blacklight::Solr::SearchBuilderBehavior
    include Hydra::AccessControlsEnforcement
    include Hyrax::SearchFilters
    include ::ExcludeDerivedPageable

    self.default_processor_chain += [:exclude_derived_pages]
  end
end
