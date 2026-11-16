# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource ArchivalDocument`
class ArchivalDocument < Hyrax::Work
  if Hyrax.config.work_include_metadata?
    include Hyrax::Schema(:core_metadata)
    include Hyrax::Schema(:basic_metadata)
    include Hyrax::Schema(:archival_document)
  end
  include HasRepresentativeThumbnail
  include WorkMemberFileSetQueries
end
