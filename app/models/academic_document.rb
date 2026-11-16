# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource AcademicDocument`
class AcademicDocument < Hyrax::Work
  if Hyrax.config.work_include_metadata?
    include Hyrax::Schema(:core_metadata)
    include Hyrax::Schema(:basic_metadata)
    include Hyrax::Schema(:academic_document)
  end
  include HasRepresentativeThumbnail
  include WorkMemberFileSetQueries
end
