# frozen_string_literal: true

module Derivatives
  module FileSetLevel
    module ThumbnailGeneration
      class FromAv < Base
      def self.supported_file_set?(file_set)
        if file_set.respond_to?(:video?) && file_set.respond_to?(:audio?)
          file_set.audio? || file_set.video?
        else
          mime_type = file_set.original_file&.mime_type.to_s
          mime_type.start_with?(MimeTypeConstants::VIDEO_MIME_PREFIX, MimeTypeConstants::AUDIO_MIME_PREFIX)
        end
      end

      private

      def thumbnail_command(source_path:, output_thumbnail_path:, mime_type:)
        [
          'ffmpeg',
          '-y',
          '-ss', '00:00:03',
          '-i', source_path,
          '-frames:v', '1',
          '-vf', 'scale=400:400:force_original_aspect_ratio=decrease',
          '-q:v', '3',
          output_thumbnail_path
        ]
      end
    end
  end
  end
end
