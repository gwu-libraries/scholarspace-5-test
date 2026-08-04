# frozen_string_literal: true

# Load all constants from concerns early to avoid autoload ordering issues
Dir.glob(Rails.root.join('app/services/concerns/constants/*.rb')).each { |file| require file }
