# frozen_string_literal: true

module FullTextIndexable
  extend ActiveSupport::Concern
  include StringNormalization

  MAX_INDEX_VALUE_CHARS = DerivativeServiceSettings.fetch(:indexing, :max_index_value_chars)

  def to_solr
    super.tap do |index_document|
      indexed_values = member_solr_documents.flat_map { |document| Array(document['all_text_tsimv']) }
      append_plain_text_to_index(index_document, indexed_values.join("\n")) if indexed_values.present?
    end
  end

  private

  def member_solr_documents
    ids = Array(resource.member_ids).map(&:to_s)
    return [] if ids.empty?

    response = Hyrax::SolrService.post(
      "{!terms f=id}#{ids.join(',')}",
      rows: ids.size,
      fl: 'id,all_text_tsimv'
    )
    response.dig('response', 'docs') || []
  end

  def append_plain_text_to_index(index_document, plain_text)
    existing_values = split_index_values(index_document)
    combined_values = existing_values + split_plain_text_for_index(plain_text)
    index_document[:all_text_tsimv] = combined_values
  end

  def split_index_values(index_document)
    Array(index_document[:all_text_tsimv]).flat_map do |value|
      split_plain_text_for_index(value)
    end
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

  def normalize_plain_text(text)
    sanitized = text.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: ' ')
    sanitized
      .gsub(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/, ' ')
      .unicode_normalize(:nfkc)
      .gsub(/\s+/, ' ')
      .strip
      .presence
  end

end
