# frozen_string_literal: true

module DerivativeJobSettings
  module_function

  def seconds(*keys)
    fetch(*keys).to_i
  end

  def config
    @config ||= Rails.application.config_for(:derivative_settings).deep_symbolize_keys.fetch(:jobs)
  end

  def fetch(*keys)
    keys.reduce(config) { |settings, key| settings.fetch(key) }
  end
end