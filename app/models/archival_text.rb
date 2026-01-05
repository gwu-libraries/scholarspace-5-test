# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource ArchivalDocument`
class ArchivalText < Hyrax::Work
  include Hyrax.Schema(:basic_metadata)
  include Hyrax.Schema(:archival_text)

  def derivative_service_class
    DerivativeServices::Archival::ArchivalTextDerivativesService
  end
end
