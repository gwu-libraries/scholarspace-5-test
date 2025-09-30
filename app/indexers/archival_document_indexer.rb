# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource ArchivalDocument`
class ArchivalDocumentIndexer < Hyrax::Indexers.PcdmObjectIndexer(
  ArchivalDocument
)
  include Hyrax.Indexer(:basic_metadata)
  include Hyrax.Indexer(:archival_document)

  # Uncomment this block if you want to add custom indexing behavior:
  def to_solr
    super.tap do |index_document|
      # There has to be a better way to do this, but essentially this looks
      # at the member_ids to find the derivatives for the file_set,
      # then if it has
      # if resource.member_ids.present?
      #   resource.member_ids.each do |mi|
      #     fs = Hyrax.query_service.find_by(id: mi)
      #     if fs.extracted_text.present?
      #       index_document["all_text_timv"] = fs.extracted_text.content
      #     end
      #   end
      # end
      # index_solr_doc(solr_doc)
    end
  end

  # def index_solr_doc
  #   object ||= @object || resource
  #   solr_doc["is_child_bsi"] ||= object.try(:is_child)
  #   solr_doc["split_from_pdf_id_ssi"] ||= object.try(:split_from_pdf_id)
  #   # rubocop:disable Style/GuardClause
  #   if respond_to?(:iiif_print_lineage_service)
  #     solr_doc["is_page_of_ssim"] = iiif_print_lineage_service.ancestor_ids_for(
  #       object
  #     )
  #     solr_doc[
  #       "descendent_member_ids_ssim"
  #     ] = iiif_print_lineage_service.descendent_member_ids_for(object)
  #   end
  # end
end
