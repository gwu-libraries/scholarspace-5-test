# frozen_string_literal: true

# Load derivative service constants early to avoid autoload ordering issues
require Rails.root.join('app/services/concerns/derivative_service_settings')
require Rails.root.join('app/services/concerns/derivative_service_constants')
