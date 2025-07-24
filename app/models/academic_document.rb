# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource AcademicDocument`
class AcademicDocument < Hyrax::Work
  include Hyrax::Schema(:basic_metadata)
  include Hyrax::Schema(:academic_document)
end
