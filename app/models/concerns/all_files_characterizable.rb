# frozen_string_literal: true

module AllFilesCharacterizable
  # essnetially does a query for every child fileset of a work, determining
  # if the metadata about the fileset exists or not, returns false
  # if any do not have metadata - either fits has not been run, or there
  # is something else amiss with the characterization

  def all_files_characterized?
    member_resources = member_ids.filter_map do |id|
      find_member_resource(id)
    end

    member_resources.all? do |member|
      if member.respond_to?(:original_file)
        member.original_file&.mime_type.present?
      elsif member.respond_to?(:file_ids)
        Array(member.file_ids).all? do |file_id|
          Hyrax.custom_queries.find_file_metadata_by(id: file_id).present?
        end
      else
        false
      end
    end
  end

  def find_member_resource(id)
    Hyrax.query_service.find_by(id: id)
  end
end