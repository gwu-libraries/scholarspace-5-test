# frozen_string_literal: true

module ExcludeDerivedPageable
  extend ActiveSupport::Concern

  def exclude_derived_pages(solr_parameters)
    return unless solr_parameters[:q] || solr_parameters[:all_fields]

    solr_parameters[:fq] ||= []
    solr_parameters[:fq] << '-has_model_tesim:DerivedPage'
  end
end
