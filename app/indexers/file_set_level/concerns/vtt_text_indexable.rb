# frozen_string_literal: true

module VttTextIndexable
  # Provides helpers for removing WebVTT formatting before text indexing.
  
  private

  def normalize_vtt_text(content)
    lines = content.lines.map(&:rstrip)
    cleaned_lines = []
    index = 0

    while index < lines.length
      line = lines[index].strip
      if line.blank? || line.casecmp('WEBVTT').zero?
        index += 1
        next
      end
      if line.match?(/\A(?:NOTE|STYLE|REGION)\b/)
        index += 1
        index += 1 while index < lines.length && lines[index].strip.present?
        next
      end
      if timestamp_line?(line) || (lines[index + 1] && timestamp_line?(lines[index + 1].strip))
        index += 1
        next
      end
      cleaned_lines << line
      index += 1
    end

    normalize_plain_text(cleaned_lines.join(' '))
  end

  def timestamp_line?(line)
    line.match?(%r{\A(?:\d{2}:)?\d{2}:\d{2}\.\d{3}\s+-->\s+(?:\d{2}:)?\d{2}:\d{2}\.\d{3}(?:\s+.*)?\z})
  end
end