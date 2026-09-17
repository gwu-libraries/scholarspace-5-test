# frozen_string_literal: true

module FileSetFileTypeDetection
  extend ActiveSupport::Concern
  include Constants::MimeTypeConstants
  include StringNormalization

  def pdf?
    mime_type = normalize_mime_type(original_file&.mime_type)
    mime_type == PDF_MIME_TYPE
  end

  def hocr?
    mime_type = normalize_mime_type(original_file&.mime_type)
    mime_type == HOCR_MIME_TYPE
  end

  def audio?
    mime_type = normalize_mime_type(original_file&.mime_type)
    mime_type.start_with?(AUDIO_MIME_PREFIX)
  end

  def video?
    mime_type = normalize_mime_type(original_file&.mime_type)
    mime_type.start_with?(VIDEO_MIME_PREFIX)
  end

  def image?
    mime_type = normalize_mime_type(original_file&.mime_type)
    mime_type.start_with?(IMAGE_MIME_PREFIX)
  end

  def vtt?
    mime_type = normalize_mime_type(original_file&.mime_type)
    mime_type == VTT_MIME_TYPE
  end

  # Returns the best available name for this file set
  def file_display_name
    original_filename = original_file&.original_filename.to_s
    return original_filename if original_filename.present?

    label_name = respond_to?(:label) ? label.to_s : ''
    return label_name if label_name.present?

    Array(title).find(&:present?).to_s
  end
end
