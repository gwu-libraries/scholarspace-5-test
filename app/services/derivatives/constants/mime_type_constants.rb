# frozen_string_literal: true

module Derivatives::Constants::MimeTypeConstants
  PDF_MIME_TYPE = Configuration::DerivativeSettings.fetch(:mime_types, :pdf)
  HOCR_MIME_TYPE = Configuration::DerivativeSettings.fetch(:mime_types, :hocr)
  VTT_MIME_TYPE = Configuration::DerivativeSettings.fetch(:mime_types, :vtt)

  AUDIO_MIME_PREFIX = Configuration::DerivativeSettings.fetch(:mime_prefixes, :audio)
  VIDEO_MIME_PREFIX = Configuration::DerivativeSettings.fetch(:mime_prefixes, :video)
  IMAGE_MIME_PREFIX = Configuration::DerivativeSettings.fetch(:mime_prefixes, :image)

  AUDIO_VISUAL_MIME_PREFIXES = [AUDIO_MIME_PREFIX, VIDEO_MIME_PREFIX].freeze
  SUPPORTED_DERIVATIVE_SOURCE_MIME_PREFIXES = [IMAGE_MIME_PREFIX, VIDEO_MIME_PREFIX, AUDIO_MIME_PREFIX].freeze
end
