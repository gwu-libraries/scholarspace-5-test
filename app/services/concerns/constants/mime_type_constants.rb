# frozen_string_literal: true

module Constants
  module MimeTypeConstants
    PDF_MIME_TYPE = 'application/pdf'
    HOCR_MIME_TYPE = 'text/vnd.hocr+html'
    VTT_MIME_TYPE = 'text/vtt'

    AUDIO_MIME_PREFIX = 'audio/'
    VIDEO_MIME_PREFIX = 'video/'
    IMAGE_MIME_PREFIX = 'image/'

    AUDIO_VIDEO_MIME_PREFIXES = [AUDIO_MIME_PREFIX, VIDEO_MIME_PREFIX].freeze
    SUPPORTED_DERIVATIVE_SOURCE_MIME_PREFIXES = [IMAGE_MIME_PREFIX, VIDEO_MIME_PREFIX, AUDIO_MIME_PREFIX].freeze
  end
end
