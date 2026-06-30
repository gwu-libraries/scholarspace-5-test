# frozen_string_literal: true

module Derivatives
  module FileSetLevel
    module ThumbnailGeneration
      class FromImage < Base
      def self.supported_file_set?(file_set)
        if file_set.respond_to?(:image?)
          file_set.image?
        else
          file_set.original_file&.mime_type.to_s.start_with?(MimeTypeConstants::IMAGE_MIME_PREFIX)
        end
      end

      private

      def thumbnail_command(source_path:, output_thumbnail_path:, mime_type:)
        [
          'magick',
          source_path,
          '-auto-orient',
          '-thumbnail', '400x400>',
          '-quality', '85',
          output_thumbnail_path
        ]
      end
    end
  end
  end
end
