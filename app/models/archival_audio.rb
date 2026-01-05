# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource ArchivalDocument`
class ArchivalAudio < Hyrax::Work
  include Hyrax.Schema(:basic_metadata)
  include Hyrax.Schema(:archival_audio)

  def derivative_service_class
    DerivativeServices::Archival::ArchivalAudioDerivativesService
  end
end
