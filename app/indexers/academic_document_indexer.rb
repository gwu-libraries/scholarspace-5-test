# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource AcademicDocument`
class AcademicDocumentIndexer < Hyrax::Indexers::PcdmObjectIndexer(AcademicDocument)
  include Hyrax::Indexer(:basic_metadata)
  include Hyrax::Indexer(:academic_document)

  # Uncomment this block if you want to add custom indexing behavior:
  #  def to_solr
  #    super.tap do |index_document|
  #      index_document[:my_field_tesim]   = resource.my_field.map(&:to_s)
  #      index_document[:other_field_ssim] = resource.other_field
  #    end
  #  end
end
