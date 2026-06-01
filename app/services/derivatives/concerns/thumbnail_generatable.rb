# frozen_string_literal: true

require 'open3'

module Derivatives
  module Concerns
    module ThumbnailGeneratable

      private

      def generate_thumbnail_file(source_path:, output_thumbnail_path:, mime_type:, error_message:)
        cmd = thumbnail_command(
          source_path: source_path,
          output_thumbnail_path: output_thumbnail_path,
          mime_type: mime_type
        )

        _stdout, stderr, status = Open3.capture3(*cmd)
        raise "#{error_message}: #{stderr}" unless status.success?

        output_thumbnail_path
      end

      def thumbnail_command(source_path:, output_thumbnail_path:, mime_type:)
        if mime_type == 'application/pdf'
          [
            'magick',
            '-density', '150',
            "#{source_path}[0]",
            '-thumbnail', '400x400>',
            '-quality', '85',
            output_thumbnail_path
          ]
        elsif mime_type.start_with?('video/')
          [
            'ffmpeg',
            '-y',
            '-ss', '00:00:03', # we're grabbing a screenshot at 3 seconds, arbitrary but probably fine
            '-i', source_path,
            '-frames:v', '1',
            '-vf', 'scale=400:400:force_original_aspect_ratio=decrease',
            '-q:v', '3',
            output_thumbnail_path
          ]
        else
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
