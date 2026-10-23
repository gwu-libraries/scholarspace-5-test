# frozen_string_literal: true

class FileSetIndexer < Hyrax::Indexers::FileSetIndexer
  include VttTextIndexable
  include OcrTextIndexable
  include EmbeddedPdfTextIndexable

  MAX_INDEX_VALUE_CHARS = Configuration::DerivativeSettings.fetch(:indexing, :max_index_value_chars)

  def to_solr
    super.tap do |index_document|
      parent_id = parent_work_id
      index_document[:parent_work_id_ssim] = parent_id.to_s if parent_id

      file = primary_file
      content = read_file_content(file) if file
      plain_text = plain_text_for_file(file, content)
      index_document[:all_text_tsimv] = split_index_values(plain_text) if plain_text.present?

      hocr_markup = hocr_markup_for_file(file, content)
      index_document[:hocr_markup] = hocr_markup if hocr_markup.present?
    end
  end

  private

  def parent_work_id
    Hyrax.custom_queries.find_parent_work_id(resource: resource)
  end

  def plain_text_for_file(file, content)
    return nil unless file

    return nil if content.blank?

    filename = file.original_filename.to_s.downcase
    return extract_hocr_plain_text(content) if filename.end_with?('.hocr')
    return normalize_vtt_text(content) if filename.end_with?('.vtt')
    return extract_pdf_plain_text(content) if filename.end_with?('.pdf')

    nil
  end

  def primary_file
    Hyrax.config.file_set_file_service.new(file_set: resource).primary_file
  end

  def read_file_content(file)
    file_identifier = file.file_identifier
    return nil if file_identifier.blank?

    Hyrax.storage_adapter.find_by(id: file_identifier)&.stream&.read
  rescue Valkyrie::Persistence::ObjectNotFoundError
    nil
  end

  def split_index_values(text)
    normalized_text = normalize_plain_text(text)
    return [] if normalized_text.blank?

    segments = []
    current = +''
    normalized_text.split.each do |token|
      if token.length > MAX_INDEX_VALUE_CHARS
        segments << current if current.present?
        current = +''
        token.scan(/.{1,#{MAX_INDEX_VALUE_CHARS}}/).each { |chunk| segments << chunk }
      elsif current.blank?
        current = token.dup
      elsif current.length + token.length + 1 <= MAX_INDEX_VALUE_CHARS
        current << " #{token}"
      else
        segments << current
        current = token.dup
      end
    end
    segments << current if current.present?
    segments
  end

  def normalize_plain_text(text)
    text.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: ' ')
      .gsub(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/, ' ')
      .unicode_normalize(:nfkc)
      .gsub(/\s+/, ' ')
      .strip
      .presence
  end
end