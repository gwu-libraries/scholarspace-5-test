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

          merged_doc = HocrDocumentMerger.merge(hocr_paths.map { |path| File.read(path) })
          return nil unless merged_doc

          output_dir = "#{@working_dir}/hocr"
          ensure_directory_exists(output_dir)
          merge_output_path = "#{output_dir}/#{joined_hocr_filename}"
          File.write(merge_output_path, merged_doc.to_xml(indent: 2))
          merge_output_path
        rescue StandardError
          nil
        end
      end
    end
  end
end
