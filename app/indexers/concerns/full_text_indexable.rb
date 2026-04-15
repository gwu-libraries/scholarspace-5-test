# frozen_string_literal: true

require 'nokogiri'

module FullTextIndexable
  extend ActiveSupport::Concern

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
    filename = file.original_filename.to_s.downcase

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
    existing_values = Array(index_document[:all_text_tsimv]).filter_map(&:presence)
    index_document[:all_text_tsimv] = existing_values + [plain_text]
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
    text.to_s
      .unicode_normalize(:nfkc)
      .gsub(/\s+/, ' ')
      .strip
      .presence
  end

  def find_member_by_id(member_id)
    Hyrax.query_service.find_by(id: member_id)
  rescue Valkyrie::Persistence::ObjectNotFoundError
    nil
  end

  def find_storage_file_by_id(file_identifier)
    Hyrax.storage_adapter.find_by(id: file_identifier)
  rescue Valkyrie::Persistence::ObjectNotFoundError
    nil
  end
end