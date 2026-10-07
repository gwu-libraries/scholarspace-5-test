# frozen_string_literal: true

class ETD < Hyrax::Work
  include Hyrax.Schema(:basic_metadata)
  include Hyrax.Schema(:etd)

  include HasRepresentativeThumbnail
  include WorkMemberFileSetQueries
end
