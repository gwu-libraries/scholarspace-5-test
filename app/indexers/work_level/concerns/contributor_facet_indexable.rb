# frozen_string_literal: true

module ContributorFacetIndexable
  # joins all non-author contributors into a 'contributor' facet.
  # this is just for searching convenience and doesn't impact how these fields are rendered on show pages

  # DISABLED FOR NOW

  # def to_solr
  #   super.tap do |index_document|
  #     contributor_values = %i[contributor advisor committee_member].flat_map do |property|
  #       next [] unless resource.respond_to?(property)

  #       Array(resource.public_send(property))
  #     end

  #     index_document[:contributor_sim] = contributor_values.map(&:to_s).reject(&:empty?).uniq
  #   end
  # end

end