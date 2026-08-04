# frozen_string_literal: true

require 'open3'

module Derivatives
  module Concerns
    module TextExtraction
      module HocrGeneratable
        private

      def generate_hocr_file(image_path:, output_hocr_path:, error_message:)
        output_base = output_hocr_path.sub(/\.hocr\z/, '')
        cmd = ['tesseract', image_path, output_base, 'hocr']

        _stdout, stderr, status = Open3.capture3(*cmd)
        raise "#{error_message}: #{stderr}" unless status.success?

        output_hocr_path
      end

      end
    end
  end
end
