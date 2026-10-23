# frozen_string_literal: true

module Derivatives::Constants::FileExtensionConstants
  AUDIO_VISUAL_EXTENSIONS = Configuration::DerivativeSettings.fetch(:file_extensions, :audio_visual).freeze
  IMAGE_EXTENSIONS = Configuration::DerivativeSettings.fetch(:file_extensions, :image).freeze

  AUDIO_VISUAL_EXTENSIONS_WITH_DOT = AUDIO_VISUAL_EXTENSIONS.map { |extension| ".#{extension}" }.freeze
  IMAGE_EXTENSIONS_WITH_DOT = IMAGE_EXTENSIONS.map { |extension| ".#{extension}" }.freeze
end
