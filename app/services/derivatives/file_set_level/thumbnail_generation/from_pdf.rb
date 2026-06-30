# frozen_string_literal: true

module Derivatives
  module FileSetLevel
    module ThumbnailGeneration
      class FromPdf < Base
      def self.supported_file_set?(file_set)
        if file_set.respond_to?(:pdf?)
          file_set.pdf?
        else
          file_set.original_file&.mime_type.to_s == MimeTypeConstants::PDF_MIME_TYPE
        end
      end

      private

      def thumbnail_command(source_path:, output_thumbnail_path:, mime_type:)
        [
          'magick',
          '-density', '150',
          "#{source_path}[0]",
          '-thumbnail', '400x400>',
          '-quality', '85',
          output_thumbnail_path
        ]
      end
    end
  end
  end
end
