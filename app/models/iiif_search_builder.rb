# frozen_string_literal: true

class IiifSearchBuilder < Blacklight::SearchBuilder
  include Blacklight::Solr::SearchBuilderBehavior

  self.default_processor_chain += [:ocr_search_params]

  def ocr_search_params(solr_parameters = {})
    solr_parameters[:facet] = false
    solr_parameters[:hl] = true
    solr_parameters[:'hl.method'] = 'unified'
    solr_parameters[:'hl.ocr.fl'] = 'ocr_text'
    solr_parameters[:'hl.snippets'] = 10
    solr_parameters[:'hl.fragsize'] = 0
    solr_parameters[:qf] = 'ocr_text'
  end
end