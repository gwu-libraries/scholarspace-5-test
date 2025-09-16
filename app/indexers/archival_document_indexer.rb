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
      if resource.member_ids.present?
        resource.member_ids.each do |mi|
          fs = Hyrax.query_service.find_by(id: mi)
          if fs.extracted_text.present?
            index_document["all_text_timv"] = fs.extracted_text.content
          end
        end
      end
    end
  end
end
