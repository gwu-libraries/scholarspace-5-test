# frozen_string_literal: true

class GwEtd < Hyrax::Work
  include Hyrax.Schema(:basic_metadata)
  include Hyrax.Schema(:academic_document)
  include Hyrax.Schema(:gw_etd)

  include HasRepresentativeThumbnail
  include WorkMemberFileSetQueries
end
