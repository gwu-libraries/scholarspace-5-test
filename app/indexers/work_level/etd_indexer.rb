# frozen_string_literal: true

class ETDIndexer < Hyrax::Indexers.PcdmObjectIndexer(
  ETD
)
  include Hyrax.Indexer(:basic_metadata)
  include Hyrax.Indexer(:etd)
  include MemberFullTextAggregatable
  include ContributorFacetIndexable
  include YearCreatedIndexable

  # Uncomment this block if you want to add custom indexing behavior:
  #  def to_solr
  #    super.tap do |index_document|
  #      index_document[:my_field_tesim]   = resource.my_field.map(&:to_s)
  #      index_document[:other_field_ssim] = resource.other_field
  #    end
  #  end
end