# frozen_string_literal: true

require 'hyrax_listener'

Hyrax.publisher.subscribe(HyraxListener.new)
