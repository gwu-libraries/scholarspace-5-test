# frozen_string_literal: true

module HighlightSearchable
  extend ActiveSupport::Concern

  def highlight_search_params(solr_parameters = {})
    return unless solr_parameters[:q] || solr_parameters[:all_fields]

    solr_parameters[:hl] = true
    solr_parameters[:'hl.fl'] = '*'
    solr_parameters[:'hl.fragsize'] = 100
    solr_parameters[:'hl.snippets'] = 5
    solr_parameters[:'hl.requiredFieldMatch'] = true
  end
end
