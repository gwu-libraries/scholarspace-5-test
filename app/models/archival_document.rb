# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource ArchivalDocument`
class ArchivalDocument < Hyrax::Work
  include Hyrax::Schema(:basic_metadata)
  include Hyrax::Schema(:archival_document)
end
