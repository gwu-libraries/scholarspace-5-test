# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource ArchivalDocument`
class ArchivalVideo < Hyrax::Work
  include Hyrax.Schema(:basic_metadata)
  include Hyrax.Schema(:archival_video)

  def derivative_service_class
    DerivativeServices::Archival::ArchivalVideoDerivativesService
  end
end
