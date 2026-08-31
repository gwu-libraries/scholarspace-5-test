# frozen_string_literal: true

module Constants
  # Fixed identifiers persisted into Solr tags, filenames, and stored metadata --
  # not environment-tunable settings, so these are plain constants rather than yml-driven.
  module DerivativeTypeConstants
    DERIVATIVE_TYPE_DEFAULT = 'derivative'
    DERIVATIVE_TYPE_HOCR = 'hocr'
    DERIVATIVE_TYPE_TRANSCRIPT = 'transcript'
    DERIVATIVE_TYPE_THUMBNAIL = 'thumbnail'
    DERIVATIVE_TYPE_PDF = 'pdf'
    DERIVATIVE_TYPE_PDF_DERIVATIVE = 'pdf_derivative'
    DERIVATIVE_TYPE_PRESENTATION_VERSION = 'presentation_version'
    PRESENTATION_VERSION_FILENAME_STEM = '_presentation_version'
    PRESENTATION_VERSION_FILENAME_FRAGMENT = "#{PRESENTATION_VERSION_FILENAME_STEM}.".freeze
  end

  module DerivativeFilenameConstants
    READING_MODE_PDF_FILENAME = 'reading_mode_pdf.pdf'
    READING_MODE_HOCR_FILENAME = 'reading_mode_pdf_HOCR.hocr'
    PDF_PRESENTATION_VERSION_SUFFIX = '_presentation_version.pdf'
  end

  module FileExtensionConstants
    AUDIO_VISUAL_EXTENSIONS = DerivativeServiceSettings.fetch(:file_extensions, :audio_visual).freeze
    IMAGE_EXTENSIONS = DerivativeServiceSettings.fetch(:file_extensions, :image).freeze

    AUDIO_VISUAL_EXTENSIONS_WITH_DOT = AUDIO_VISUAL_EXTENSIONS.map { |extension| ".#{extension}" }.freeze
    IMAGE_EXTENSIONS_WITH_DOT = IMAGE_EXTENSIONS.map { |extension| ".#{extension}" }.freeze
  end

  module MimeTypeConstants
    PDF_MIME_TYPE = DerivativeServiceSettings.fetch(:mime_types, :pdf)
    HOCR_MIME_TYPE = DerivativeServiceSettings.fetch(:mime_types, :hocr)
    VTT_MIME_TYPE = DerivativeServiceSettings.fetch(:mime_types, :vtt)

    AUDIO_MIME_PREFIX = DerivativeServiceSettings.fetch(:mime_prefixes, :audio)
    VIDEO_MIME_PREFIX = DerivativeServiceSettings.fetch(:mime_prefixes, :video)
    IMAGE_MIME_PREFIX = DerivativeServiceSettings.fetch(:mime_prefixes, :image)

    AUDIO_VISUAL_MIME_PREFIXES = [AUDIO_MIME_PREFIX, VIDEO_MIME_PREFIX].freeze
    SUPPORTED_DERIVATIVE_SOURCE_MIME_PREFIXES = [IMAGE_MIME_PREFIX, VIDEO_MIME_PREFIX, AUDIO_MIME_PREFIX].freeze
  end

  module ThumbnailFilenameConstants
    REPRESENTATIVE_THUMBNAIL_FILENAME = 'REPRESENTATIVE_THUMBNAIL.jpg'
    GENERATED_THUMBNAIL_SUFFIX = '_THUMBNAIL.jpg'
  end

  module ThumbnailTagConstants
    THUMBNAIL_DERIVATIVE_TAG = 'derivative_type:thumbnail'
    THUMBNAIL_DERIVATIVE_PREFIX = 'derivative_type:'
    REPRESENTATIVE_THUMBNAIL_TAG_PREFIX = 'representative_thumbnail_for_work:'
    SOURCE_FILE_SET_ID_PREFIX = 'source_file_set_id:'
    THUMBNAIL_FILENAME_FRAGMENT = '_thumbnail.'
  end
end

DerivativeServiceConstants = Constants unless defined?(DerivativeServiceConstants)