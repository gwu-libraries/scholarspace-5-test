# frozen_string_literal: true

require 'nokogiri'

# Combines per-page hOCR documents into one document, renumbering element ids so
# each page id stays unique. Tesseract emits `page_1` for every file it writes,
# and the Solr OCR highlighting plugin needs unique page ids to attribute a match
# to the right page.
class HocrDocumentMerger
  def self.merge(contents)
    new(contents).merge
  end

  def initialize(contents)
    @contents = Array(contents).reject(&:blank?)
  end

  def merge
    return nil if @contents.empty?

    document = base_document
    @contents.each_with_index do |content, index|
      page = page_element(content)
      next unless page

      cloned_page = page.dup
      renumber_ids(cloned_page, index + 1)
      document.at('body') << cloned_page
    end

    document
  end

  private

  def page_element(content)
    Nokogiri::HTML(content, nil, 'UTF-8').at('div.ocr_page')
  rescue StandardError => e
    Rails.logger.warn("Skipping unparseable hOCR content: #{e.message}")
    nil
  end

  def base_document
    # this is just like the standard boilerplate 
    html = <<~HTML
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
          "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
      <html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
       <head>
        <title>Reading Mode PDF</title>
        <meta http-equiv="Content-Type" content="text/html;charset=utf-8"/>
        <meta name='ocr-system' content='tesseract'/>
        <meta name='ocr-capabilities' content='ocr_page ocr_carea ocr_par ocr_line ocrx_word ocrp_dir ocrp_lang ocrp_wconf'/>
       </head>
       <body>
       </body>
      </html>
    HTML

    Nokogiri::HTML(html, nil, 'UTF-8')
  end

  def renumber_ids(element, page_number)
    element['id'] = "page_#{page_number}" if element['id']&.start_with?('page_')

    element.xpath('.//*[@id]').each do |child|
      old_id = child['id']
      next unless old_id&.match?(/^(block|par|line|word|carea)_\d+_/)

      child['id'] = old_id.sub(/^(\w+)_\d+_/, "\\1_#{page_number}_")
    end
  end
end
