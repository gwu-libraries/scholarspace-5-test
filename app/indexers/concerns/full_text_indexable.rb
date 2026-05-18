# frozen_string_literal: true

require 'nokogiri'

module FullTextIndexable
  extend ActiveSupport::Concern
  include MemberQueries
  include StringNormalization

  MAX_INDEX_VALUE_CHARS = 3000
  MAX_INDEX_SEGMENTS = 24
  MAX_TOTAL_INDEX_CHARS = 24_000

  def to_solr
    super.tap do |index_document|
      full_text = extract_full_text_content
      append_plain_text_to_index(index_document, full_text) if full_text.present?
    end
  end

  private

  def extract_full_text_content
    text_segments = resource.member_ids.filter_map do |member_id|
      member = find_member_by_id(member_id)
      next unless member

      full_text_for_member(member)
    end

    text_segments.join("\n").presence
  end

  def full_text_for_member(member)
    text_segments = []

    file = member.original_file if member.respond_to?(:original_file)
    if file
      file_content = read_file_content(file)
      if file_content.present?
        extracted_file_text = extract_file_text(file: file, content: file_content)
        text_segments << extracted_file_text if extracted_file_text.present?
      end
    end

    extracted_text_content = extract_extracted_text_content(member)
    text_segments << normalize_plain_text(extracted_text_content) if extracted_text_content.present?

    text_segments.join("\n").presence
  end

  def extract_file_text(file:, content:)
    filename = normalize_filename(file.original_filename)

    if filename.end_with?('.hocr')
      extract_hocr_plain_text(content)
    end
  end

  def extract_extracted_text_content(member)
    return unless member.respond_to?(:extracted_text_id)
    return if member.extracted_text_id.blank?

    Hyrax.custom_queries.find_extracted_text(file_set: member)&.content
  rescue Valkyrie::Persistence::ObjectNotFoundError
    nil
  end

  def extract_hocr_plain_text(content)
    document = Nokogiri::HTML(content, nil, 'UTF-8')
    words = document.css('span.ocrx_word, span.ocr_word').filter_map do |word_node|
      normalize_plain_text(word_node.text)
    end

    return words.join(' ') if words.any?

    normalize_plain_text(document.at('body')&.text || document.text)
  end

  def append_plain_text_to_index(index_document, plain_text)
    existing_values = split_index_values(index_document)
    combined_values = existing_values + split_plain_text_for_index(plain_text)
    index_document[:all_text_tsimv] = bounded_index_segments(combined_values)
  end

  def split_index_values(index_document)
    Array(index_document[:all_text_tsimv]).flat_map do |value|
      split_plain_text_for_index(value)
    end
  end

  def bounded_index_segments(combined_values)
    # Guardrail: keep full-text payload bounded so Solr analysis does not reject
    # the entire document update for very large OCR extracts.
    bounded_values = []
    total_chars = 0

    combined_values.each do |segment|
      break if bounded_values.length >= MAX_INDEX_SEGMENTS

      normalized_segment = normalize_plain_text(segment)
      next if normalized_segment.blank?

      remaining_chars = MAX_TOTAL_INDEX_CHARS - total_chars
      break if remaining_chars <= 0

      truncated_segment = truncate_segment(normalized_segment, remaining_chars)
      next if truncated_segment.blank?

      bounded_values << truncated_segment
      total_chars += truncated_segment.length
    end

    bounded_values
  end

  def truncate_segment(segment, max_chars)
    return segment if segment.length <= max_chars

    normalize_plain_text(segment[0, max_chars])
  end

  def split_plain_text_for_index(text, max_chars: MAX_INDEX_VALUE_CHARS)
    normalized_text = normalize_plain_text(text)
    return [] if normalized_text.blank?

    segments = []
    current_segment = +''

    normalized_text.split.each do |token|
      if token.length > max_chars
        segments << current_segment if current_segment.present?
        current_segment = +''
        token.scan(/.{1,#{max_chars}}/).each { |chunk| segments << chunk }
        next
      end

      if current_segment.blank?
        current_segment = token.dup
      elsif current_segment.length + token.length + 1 <= max_chars
        current_segment << " #{token}"
      else
        segments << current_segment
        current_segment = token.dup
      end
    end

    segments << current_segment if current_segment.present?
    segments
  end

  def read_file_content(file)
    return nil unless file.respond_to?(:file_identifier)

    file_identifier = file.file_identifier
    return nil if file_identifier.blank?

    io = find_storage_file_by_id(file_identifier)
    return nil unless io

    io.stream.read
  end

  def normalize_plain_text(text)
    sanitized = text.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: ' ')
    sanitized
      .gsub(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/, ' ')
      .unicode_normalize(:nfkc)
      .gsub(/\s+/, ' ')
      .strip
      .presence
  end



  def find_storage_file_by_id(file_identifier)
    Hyrax.storage_adapter.find_by(id: file_identifier)
  rescue Valkyrie::Persistence::ObjectNotFoundError
    nil
  end
end