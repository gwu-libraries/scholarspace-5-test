# frozen_string_literal: true

module FileSetFileTypeDetection
  extend ActiveSupport::Concern
  include StringNormalization

  def pdf?
    mime_type = normalize_mime_type(original_file&.mime_type)
    filename = normalize_filename(file_display_name)
    mime_type == 'application/pdf' || filename.end_with?('.pdf')
  end

  def hocr?
    mime_type = normalize_mime_type(original_file&.mime_type)
    filename = normalize_filename(file_display_name)
    mime_type == 'text/vnd.hocr+html' || filename.end_with?('.hocr')
  end

  def audio?
    mime_type = normalize_mime_type(original_file&.mime_type)
    mime_type.start_with?('audio/')
  end

  def video?
    mime_type = normalize_mime_type(original_file&.mime_type)
    mime_type.start_with?('video/')
  end

  def image?
    mime_type = normalize_mime_type(original_file&.mime_type)
    mime_type.start_with?('image/')
  end

  def vtt?
    filename = normalize_filename(file_display_name)
    filename.end_with?('.vtt')
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
