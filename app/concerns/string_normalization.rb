# frozen_string_literal: true

# Provides methods for string normalization and comparison.
# Consolidates patterns like .to_s.downcase, file extension checking, etc.
module StringNormalization
  # Safely normalize a string to lowercase
  def normalize_string(str)
    str.to_s.downcase
  end

  # Normalize a filename to lowercase for comparison
  def normalize_filename(filename)
    normalize_string(filename)
  end

  # Normalize a MIME type to lowercase for comparison
  def normalize_mime_type(mime_type)
    normalize_string(mime_type)
  end

  # Check if filename ends with any of the given extensions (case-insensitive)
  # Extensions should not include the dot, or it will be matched literally
  def matches_extension?(filename, *extensions)
    normalized_name = normalize_filename(filename)
    extensions.any? do |ext|
      normalized_name.end_with?(".#{ext.downcase.delete_prefix('.')}")
    end
  end

  # Check if a normalized string equals another value (case-insensitive)
  def normalized_equals?(str, value)
    normalize_string(str) == normalize_string(value)
  end

  # Check if a normalized string starts with a prefix (case-insensitive)
  def normalized_starts_with?(str, prefix)
    normalize_string(str).start_with?(normalize_string(prefix))
  end
end