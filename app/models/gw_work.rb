# frozen_string_literal: true

class GwWork < Hyrax::Work
  include Hyrax.Schema(:basic_metadata)
  include Hyrax.Schema(:academic_document)
  include Hyrax.Schema(:gw_work)
end
