# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource ArchivalDocument`
class ArchivalImage < Hyrax::Work
  include Hyrax.Schema(:basic_metadata)
  include Hyrax.Schema(:archival_image)

  def derivative_service_class
    DerivativeServices::Archival::ArchivalImageDerivativesService
  end
end
