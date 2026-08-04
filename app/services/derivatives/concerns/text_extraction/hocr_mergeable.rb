# frozen_string_literal: true

require 'nokogiri'

module Derivatives
  module Concerns
    module TextExtraction
      module HocrMergeable
        include FileOperations

        private

      def merge_hocr_files(hocr_paths)
        return nil if hocr_paths.empty?

        hocr_paths = hocr_paths.select { |path| File.exist?(path) }
        return nil if hocr_paths.empty?

        merged_doc = build_merged_hocr_document(hocr_paths)
        return nil unless merged_doc

        output_dir = "#{@working_dir}/hocr"
        ensure_directory_exists(output_dir)
        merge_output_path = "#{output_dir}/#{joined_hocr_filename}"
        File.write(merge_output_path, merged_doc.to_xml(indent: 2))
        merge_output_path
      rescue StandardError
        nil
      end

      def build_merged_hocr_document(hocr_paths)
        # Create base document structure
        merged_doc = create_base_hocr_document

        # Extract and merge ocr_page divs from each file
        hocr_paths.each_with_index do |hocr_path, page_index|
          doc = Nokogiri::HTML(File.read(hocr_path), nil, 'UTF-8')
          ocr_page = doc.at('div.ocr_page')
          next unless ocr_page

          # Clone the page and renumber all IDs
          cloned_page = ocr_page.dup
          renumber_hocr_ids(cloned_page, page_index + 1)

          # Append to merged document body
          merged_doc.at('body') << cloned_page
        end

        merged_doc
      end

      def create_base_hocr_document
        html = <<~HTML
          <?xml version="1.0" encoding="UTF-8"?>
          <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
              "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
          <html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
           <head>
            <title>Combined OCR Document</title>
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

      def renumber_hocr_ids(element, page_number)
        # Renumber the ocr_page div id
        if element['id']&.start_with?('page_')
          element['id'] = "page_#{page_number}"
        end

        # Recursively renumber all child elements with 'id' attributes
        element.xpath('.//*[@id]').each do |child|
          old_id = child['id']
          next unless old_id&.match?(/^(block|par|line|word|carea)_\d+_/)

          # Replace the first number (block level) with page number
          # e.g., "block_1_1" becomes "block_2_1" for page 2
          new_id = old_id.sub(/^(\w+)_\d+_/, "\\1_#{page_number}_")
          child['id'] = new_id
        end

        # Also update any references in title attributes that might contain IDs
        element.xpath('.//*[@title]').each do |child|
          title = child['title']
          next unless title

          child['title'] = title
        end
      end

      end
    end
  end
end
