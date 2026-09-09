# frozen_string_literal: true

module WorkMemberFileSetQueries
  extend ActiveSupport::Concern

  # Returns all member file sets for this work
  def member_file_sets
    Array(member_ids).filter_map { |id| find_member_file_set(id) }
  end

  # Returns only non-service member file sets (original uploads, not derivatives)
  def original_member_file_sets
    member_file_sets.reject(&:service_file)
  end

  # Find a specific member file set by ID
  def find_member_file_set(file_set_id)
    Hyrax.query_service.find_by(id: file_set_id)
  rescue Valkyrie::Persistence::ObjectNotFoundError
    nil
  end

  # Check if all files have been characterized
  def all_files_characterized?
    child_works = member_ids.map { |id| Hyrax.query_service.find_by(id: id) }

    child_works_metadata =
      child_works.map do |cw|
        cw&.file_ids&.first&.then do |file_id|
          Hyrax.custom_queries.find_file_metadata_by(id: file_id)
        end
      end

    child_works_metadata.any?(&:nil?) ? false : true
  rescue StandardError
    false
  end
end