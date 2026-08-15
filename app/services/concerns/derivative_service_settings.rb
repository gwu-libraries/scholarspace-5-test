# frozen_string_literal: true

module DerivativeServiceSettings
  module_function

  def config
    @config ||= Rails.application.config_for(:derivative_services).deep_symbolize_keys
  end

  def fetch(*keys)
    keys.reduce(config) { |settings, key| settings.fetch(key) }
  end
end