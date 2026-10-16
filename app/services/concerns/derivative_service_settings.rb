# frozen_string_literal: true

module DerivativeServiceSettings
  module_function

  def config
    @config ||= Rails.application.config_for(:derivative_settings).deep_symbolize_keys.fetch(:services)
  end

  def fetch(*keys)
    keys.reduce(config) { |settings, key| settings.fetch(key) }
  end

  def transcription_model
    fetch(:transcription, :model)
  end

  def video_encoding_arguments
    settings = fetch(:presentation_version, :video)
    ['-preset', settings.fetch(:preset), '-crf', settings.fetch(:crf).to_s]
  end
end