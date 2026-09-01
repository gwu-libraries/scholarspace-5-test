# frozen_string_literal: true

module MemberQueries
  extend ActiveSupport::Concern

  # Find a member (file set) by ID from the index service
  def find_member_by_id(member_id)
    Hyrax.query_service.find_by(id: member_id)
  rescue Valkyrie::Persistence::ObjectNotFoundError
    nil
  end

  # Find a storage file by ID
  def find_storage_file_by_id(file_identifier)
    Hyrax.storage_adapter.find_by(id: file_identifier)
  rescue Valkyrie::Persistence::ObjectNotFoundError
    nil
  end
end
