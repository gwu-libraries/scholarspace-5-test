# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource ArchivalDocument`
class ArchivalDocument < Hyrax::Work
  include Hyrax::Schema(:basic_metadata)
  include Hyrax::Schema(:archival_document)

  def all_files_characterized?
    child_works = member_ids.map { |id| Hyrax.query_service.find_by(id: id) }

    child_works_metadata =
      child_works.map do |cw|
        cw&.file_ids&.first&.then do |file_id|
          Hyrax.custom_queries.find_file_metadata_by(id: file_id)
        end
      end

    child_works_metadata.any?(&:nil?) ? false : true
  end
end
