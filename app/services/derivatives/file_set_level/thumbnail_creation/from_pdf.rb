# frozen_string_literal: true

require 'open3'

module Derivatives
  module FileSetLevel
    module ThumbnailCreation
      class FromPdf
        include FileOperations
        include ::Constants::ThumbnailFilenameConstants

        def self.supported_file_set?(file_set)
          if file_set.respond_to?(:pdf?)
            file_set.pdf?
          else
            file_set.original_file&.mime_type.to_s == Constants::MimeTypeConstants::PDF_MIME_TYPE
          end
        end

        def initialize(work, working_dir:)
          @work = work
          @working_dir = working_dir
        end

        def generate_thumbnail_asset(source_file_set, thumbnail_filename)
          source_path = copy_source_to_working_dir(source_file_set)
          return nil unless source_path

          output_path = File.join(@working_dir, thumbnail_filename)
          generate_thumbnail_file(
            source_path: source_path,
            output_thumbnail_path: output_path,
            error_message: "Unable to generate thumbnail for file set #{source_file_set.id}"
          )
          output_path
        end

        def thumbnail_filename_for(file_set)
          original_filename = file_set.original_file&.original_filename.to_s
          stem = File.basename(original_filename, File.extname(original_filename))
          sanitized = stem.gsub(/[^0-9A-Za-z.-]+/, '_').gsub(/\A_+|_+\z/, '')
          sanitized = 'source' if sanitized.blank?
          "#{sanitized}#{GENERATED_THUMBNAIL_SUFFIX}"
        end

        def copy_source_to_working_dir(file_set)
          original_file = file_set.original_file
          return nil unless original_file&.file_identifier

          extension = File.extname(original_file.original_filename.to_s)
          extension = '.bin' if extension.blank?
          source_path = File.join(@working_dir, "#{file_set.id}#{extension}")

          copy_file_to_disk(original_file.file_identifier, source_path)
        end

        private

        def generate_thumbnail_file(source_path:, output_thumbnail_path:, error_message:)
          _stdout, stderr, status = Open3.capture3(*thumbnail_command(
            source_path: source_path,
            output_thumbnail_path: output_thumbnail_path
          ))
          raise "#{error_message}: #{stderr}" unless status.success?

          output_thumbnail_path
        end

        def thumbnail_command(source_path:, output_thumbnail_path:)
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
