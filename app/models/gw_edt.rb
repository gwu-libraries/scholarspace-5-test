# frozen_string_literal: true

class GwEtd < AcademicDocument
  include Hyrax.Schema(:basic_metadata)
  include Hyrax.Schema(:academic_document)
  include Hyrax.Schema(:gw_etd)
end
