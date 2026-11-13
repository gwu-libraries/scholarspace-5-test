# frozen_string_literal: true

require 'nokogiri'

module OcrTextIndexable
  # included by FileSetIndexer to identify HOCR files and convert their markup
  # into normalized plain text for indexing.
  private

  def hocr_markup_for_file(file, content)
    return nil unless file && file.original_filename.to_s.downcase.end_with?('.hocr')

    content
  end

  def extract_hocr_plain_text(content)
    document = Nokogiri::HTML(content, nil, 'UTF-8')
    words = document.css('span.ocrx_word, span.ocr_word').filter_map { |node| normalize_plain_text(node.text) }
    return words.join(' ') if words.any?

    normalize_plain_text(document.at('body')&.text || document.text)
  end
end