# frozen_string_literal: true

module VttIndexable
  extend ActiveSupport::Concern
  include MemberQueries
  include FileOperations

  def to_solr
    super.tap do |index_document|
      vtt_content = extract_vtt_content
      index_document[:vtt_text_tesim] = vtt_content if vtt_content.present?
    end
  end

  private

  def extract_vtt_content
    vtt_content = resource.member_ids.filter_map do |member_id|
      member = find_member_by_id(member_id)
      next unless member
      next unless member.respond_to?(:original_file)

      file = member.original_file
      next unless file
      next unless vtt_file?(file)

      normalize_vtt_text(read_file_content(file))
    end.compact

    vtt_content.join("\n") if vtt_content.any?
  end

  def vtt_file?(file)
    return false unless file.respond_to?(:original_filename)

    filename = file.original_filename.to_s
    return false if filename.empty?

    filename.downcase.end_with?('.vtt')
  end

  def read_file_content(file)
    return nil unless file.respond_to?(:file_identifier)

    file_identifier = file.file_identifier
    return nil if file_identifier.blank?

    io = find_storage_file_by_id(file_identifier)
    return nil unless io

    io.stream.read
  end

  def find_storage_file_by_id(file_identifier)
    Hyrax.storage_adapter.find_by(id: file_identifier)
  rescue Valkyrie::Persistence::ObjectNotFoundError
    nil
  end

  def normalize_vtt_text(content)
    # strip out the metadata and non-word content of the vtt file for just indexing text
    return nil if content.blank?

    lines = content.lines.map(&:rstrip)
    cleaned_lines = []
    index = 0

    while index < lines.length
      line = lines[index].strip

      if line.blank? || line.casecmp('WEBVTT').zero?
        index += 1
        next
      end

      if block_metadata_line?(line)
        index += 1
        index += 1 while index < lines.length && lines[index].strip.present?
        next
      end

      if cue_identifier_line?(line, lines[index + 1]) || timestamp_line?(line)
        index += 1
        next
      end

      cleaned_lines << line
      index += 1
    end

    cleaned = cleaned_lines.join(' ').unicode_normalize(:nfkc).gsub(/\s+/, ' ').strip
    cleaned.presence
  end

  def block_metadata_line?(line)
    line.match?(/\A(?:NOTE|STYLE|REGION)\b/)
  end

  def cue_identifier_line?(line, next_line)
    return false if next_line.blank?
    return false if line.include?('-->')

    timestamp_line?(next_line.to_s.strip)
  end

  def timestamp_line?(line)
    line.match?(%r{\A(?:\d{2}:)?\d{2}:\d{2}\.\d{3}\s+-->\s+(?:\d{2}:)?\d{2}:\d{2}\.\d{3}(?:\s+.*)?\z})
  end
end
