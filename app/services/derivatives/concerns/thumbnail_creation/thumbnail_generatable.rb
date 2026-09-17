# frozen_string_literal: true

require 'open3'
require 'timeout'

module Derivatives
  module Concerns
    module ThumbnailCreation
      module ThumbnailGeneratable
        TIMEOUT_SECONDS = DerivativeJobSettings.seconds(:thumbnail_generation, :timeout_seconds)
        PLACEHOLDER_GEOMETRY = DerivativeServiceSettings.fetch(:thumbnails, :placeholder_geometry)
        PLACEHOLDER_COLOR = DerivativeServiceSettings.fetch(:thumbnails, :placeholder_color)

        private

        def generate_placeholder_thumbnail_file(output_thumbnail_path:)
          _stdout, stderr, status = Timeout.timeout(TIMEOUT_SECONDS) do
            Open3.capture3('magick', '-size', PLACEHOLDER_GEOMETRY, PLACEHOLDER_COLOR, output_thumbnail_path)
          end
          raise "Placeholder thumbnail generation failed: #{stderr}" unless status.success?

          output_thumbnail_path
        end

        # ffmpeg and magick can hang indefinitely on damaged input, which would hold
        # the worker until ECS kills the task.
        def generate_thumbnail_file(source_path:, output_thumbnail_path:, error_message:)
          _stdout, stderr, status = Timeout.timeout(TIMEOUT_SECONDS) do
            Open3.capture3(*thumbnail_command(
              source_path: source_path,
              output_thumbnail_path: output_thumbnail_path
            ))
          end
          raise "#{error_message}: #{stderr}" unless status.success?

          output_thumbnail_path
        rescue Timeout::Error
          raise "#{error_message}: timed out after #{TIMEOUT_SECONDS}s"
        end
      end
    end
  end
end
