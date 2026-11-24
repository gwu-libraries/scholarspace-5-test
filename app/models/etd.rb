# frozen_string_literal: true

class ETD < Hyrax::Work
  if Hyrax.config.work_include_metadata?
    include Hyrax::Schema(:core_metadata)
    include Hyrax::Schema(:basic_metadata)
    include Hyrax::Schema(:etd)
  end

  include HasRepresentativeThumbnail
  include WorkMemberFileSetQueries
end
