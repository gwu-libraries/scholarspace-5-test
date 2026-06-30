# frozen_string_literal: true

module DerivativeTypeConstants
  DERIVATIVE_TYPE_DEFAULT = 'derivative'
  DERIVATIVE_TYPE_HOCR = 'hocr'
  DERIVATIVE_TYPE_TRANSCRIPT = 'transcript'
  DERIVATIVE_TYPE_THUMBNAIL = 'thumbnail'
  DERIVATIVE_TYPE_PDF = 'pdf'
  DERIVATIVE_TYPE_PDF_DERIVATIVE = 'pdf_derivative'
  DERIVATIVE_TYPE_PRESENTATION_VERSION = 'presentation_version'
  PRESENTATION_VERSION_FILENAME_STEM = '_presentation_version'.freeze
  PRESENTATION_VERSION_FILENAME_FRAGMENT = "#{PRESENTATION_VERSION_FILENAME_STEM}.".freeze
end