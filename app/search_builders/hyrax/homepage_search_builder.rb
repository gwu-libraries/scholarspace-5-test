# frozen_string_literal: true

module Hyrax
  class HomepageSearchBuilder < ::SearchBuilder
    include Blacklight::Solr::SearchBuilderBehavior
    include Hydra::AccessControlsEnforcement
    include Hyrax::SearchFilters
    include ::ExcludeDerivedPageable

    self.default_processor_chain += [:add_access_controls_to_solr_params]

    def only_works?
      true
    end
  end
end
