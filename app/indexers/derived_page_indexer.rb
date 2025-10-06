# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource Page`
class DerivedPageIndexer < Hyrax::Indexers.PcdmObjectIndexer(DerivedPage)
  include Hyrax.Indexer(:basic_metadata)
  include Hyrax.Indexer(:derived_page)

  # Uncomment this block if you want to add custom indexing behavior:
  def to_solr
    super.tap do |index_document|
      # if resource.representative_id.present?
      # file_sets =
      #   Hyrax
      #     .query_service
      #     .find_members(resource: resource)
      #     .select { |member| member.is_a?(Hyrax::FileSet) }
      #     .force

      # if file_sets.present?
      #   path =
      #     Hyrax::DerivativePath.derivative_path_for_reference(
      #       file_sets.first.id,
      #       "xml"
      #     )
      #   index_document[:ocr_text] = path
      # end
    end
  end
end
