# frozen_string_literal: true

module WorkMemberFileSetQueries
  extend ActiveSupport::Concern

  def member_file_sets
    # The way I was handling this was a problem, causing recursive Fedora queries

    # quite possibly should just be a solr query, but we may need to have the option to query from fedora
  
    ids = Array(member_ids).map(&:to_s)
    return @member_file_sets_cache[:file_sets] if @member_file_sets_cache && @member_file_sets_cache[:ids] == ids

    file_sets = ids.filter_map { |id| find_member_file_set(id) }
    @member_file_sets_cache = { ids: ids, file_sets: file_sets }
    file_sets
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
end