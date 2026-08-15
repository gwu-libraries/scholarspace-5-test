# frozen_string_literal: true

module Constants
  module DerivativeTypeConstants
    DERIVATIVE_TYPE_DEFAULT = DerivativeServiceSettings.fetch(:derivative_types, :default)
    DERIVATIVE_TYPE_HOCR = DerivativeServiceSettings.fetch(:derivative_types, :hocr)
    DERIVATIVE_TYPE_TRANSCRIPT = DerivativeServiceSettings.fetch(:derivative_types, :transcript)
    DERIVATIVE_TYPE_THUMBNAIL = DerivativeServiceSettings.fetch(:derivative_types, :thumbnail)
    DERIVATIVE_TYPE_PDF = DerivativeServiceSettings.fetch(:derivative_types, :pdf)
    DERIVATIVE_TYPE_PDF_DERIVATIVE = DerivativeServiceSettings.fetch(:derivative_types, :pdf_derivative)
    DERIVATIVE_TYPE_PRESENTATION_VERSION = DerivativeServiceSettings.fetch(:derivative_types, :presentation_version)
    PRESENTATION_VERSION_FILENAME_STEM = DerivativeServiceSettings.fetch(:derivative_filenames, :presentation_version_stem).freeze
    PRESENTATION_VERSION_FILENAME_FRAGMENT = "#{PRESENTATION_VERSION_FILENAME_STEM}.".freeze
  end

  module DerivativeFilenameConstants
    READING_MODE_PDF_FILENAME = DerivativeServiceSettings.fetch(:derivative_filenames, :reading_mode_pdf)
    READING_MODE_HOCR_FILENAME = DerivativeServiceSettings.fetch(:derivative_filenames, :reading_mode_hocr)
    PDF_PRESENTATION_VERSION_SUFFIX = DerivativeServiceSettings.fetch(:derivative_filenames, :pdf_presentation_version_suffix)
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
    REPRESENTATIVE_THUMBNAIL_FILENAME = DerivativeServiceSettings.fetch(:thumbnail_filenames, :representative)
    GENERATED_THUMBNAIL_SUFFIX = DerivativeServiceSettings.fetch(:thumbnail_filenames, :generated_suffix)
  end

  module ThumbnailTagConstants
    THUMBNAIL_DERIVATIVE_TAG = DerivativeServiceSettings.fetch(:thumbnail_tags, :derivative_tag)
    THUMBNAIL_DERIVATIVE_PREFIX = DerivativeServiceSettings.fetch(:thumbnail_tags, :derivative_prefix)
    REPRESENTATIVE_THUMBNAIL_TAG_PREFIX = DerivativeServiceSettings.fetch(:thumbnail_tags, :representative_prefix)
    SOURCE_FILE_SET_ID_PREFIX = DerivativeServiceSettings.fetch(:thumbnail_tags, :source_file_set_id_prefix)
    THUMBNAIL_FILENAME_FRAGMENT = DerivativeServiceSettings.fetch(:thumbnail_tags, :filename_fragment)
  end
end

DerivativeServiceConstants = Constants unless defined?(DerivativeServiceConstants)