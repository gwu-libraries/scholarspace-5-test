# frozen_string_literal: true

require 'open3'

module Derivatives
  module FileSetLevel
    module PresentationVersion
      class FromImage
        include ::Constants::DerivativeTypeConstants
        include ::Constants::FileExtensionConstants
        include ::Constants::MimeTypeConstants
        include Concerns::FileSetAttachable
        include Derivatives::Concerns::SourceFileSetMimeDetection
        include FileOperations
        include PersistenceAdapter

        IMAGE_EXTENSIONS_FOR_PRESENTATION = {
          '.jpg' => '.jpg',
          '.jpeg' => '.jpg',
          '.png' => '.png',
          '.webp' => '.webp'
        }.freeze

        def initialize(work)
          @work = work
        end

        def source_file_set_ids
          source_file_sets.map { |file_set| file_set.id.to_s }
        end

        def generate_to_cache(source_file_set_id:)
          source_file_set = source_file_set_for(source_file_set_id)
          raise "Image presentation source file set not found: #{source_file_set_id}" unless source_file_set
          raise 'Image presentation depositor not found' unless depositor

          Dir.mktmpdir("presentation_image_#{@work.id}_") do |dir|
            source_path = copy_source_to_path(source_file_set, dir: dir)
            filename = presentation_filename(source_file_set, extension: output_extension(source_file_set))
            output_path = File.join(dir, filename)

            build_presentation(source_path: source_path, output_path: output_path)
            return nil unless File.exist?(output_path)

            cache_payload(source_file_set: source_file_set, output_path: output_path, filename: filename)
          end
        end

        def persist_from_cache(source_file_set_id:, cache_file_identifier:, cache_filename:)
          source_file_set = source_file_set_for(source_file_set_id)
          raise "Image presentation source file set not found: #{source_file_set_id}" unless source_file_set
          raise 'Image presentation depositor not found' unless depositor

          Dir.mktmpdir("presentation_persist_#{@work.id}_") do |dir|
            cached_io = DerivativeCacheService.instance.fetch_stream(
              file_identifier: cache_file_identifier,
              original_filename: cache_filename
            )
            raise "Image presentation cache missing: #{cache_file_identifier}" unless cached_io

            output_path = File.join(dir, cache_filename)
            File.open(output_path, 'wb') { |io| IO.copy_stream(cached_io, io) }

            existing = linked_presentation_file_set(source_file_set: source_file_set, filename: cache_filename)
            persisted_file_set = if existing
              replace_file_set_file(file_set: existing, file_path: output_path, user: depositor)
            else
              attach_single_file_to_work(
                file_path: output_path,
                user: depositor,
                service_file: true,
                source_file_set: source_file_set,
                derivative_type_override: DERIVATIVE_TYPE_PRESENTATION_VERSION
              )
            end

            reindex_work_and_file_set(persisted_file_set) if persisted_file_set
          ensure
            cached_io&.close
          end
        end

        private

        def source_file_sets
          @work.member_file_sets.select do |file_set|
            !file_set.service_file && source_image_file_set?(file_set)
          end
        end

        def source_file_set_for(source_file_set_id)
          source_file_sets.find { |file_set| file_set.id.to_s == source_file_set_id.to_s }
        end

        def copy_source_to_path(source_file_set, dir:)
          original_filename = source_file_set.original_file&.original_filename.to_s
          extension = File.extname(original_filename)
          extension = '.bin' if extension.blank?
          source_path = File.join(dir, "#{source_file_set.id}#{extension}")
          copy_file_to_disk(source_file_set.original_file.file_identifier, source_path)
          source_path
        end

        def output_extension(source_file_set)
          original_ext = File.extname(source_file_set.original_file&.original_filename.to_s).downcase
          IMAGE_EXTENSIONS_FOR_PRESENTATION.fetch(original_ext, '.jpg')
        end

        def presentation_filename(source_file_set, extension:)
          original_filename = source_file_set.original_file&.original_filename.to_s
          base_name = File.basename(original_filename, File.extname(original_filename))
          "#{base_name}#{PRESENTATION_VERSION_FILENAME_STEM}#{extension}"
        end

        def build_presentation(source_path:, output_path:)
          cmd = ['magick', 'convert', source_path, '-strip']

          case File.extname(output_path).downcase
          when '.jpg', '.jpeg'
            cmd += ['-interlace', 'Plane', '-quality', '82']
          when '.png'
            cmd += ['-define', 'png:compression-level=9']
          when '.webp'
            cmd += ['-quality', '80']
          end

          cmd << output_path
          _stdout, stderr, status = Open3.capture3(*cmd)
          return if status.success?

          raise "Unable to create image presentation version: #{stderr.to_s.strip.truncate(300)}"
        end

        def reindex_work_and_file_set(file_set)
          @work = save_and_index(@work)
          index_resources([file_set])
        end

        def linked_presentation_file_set(source_file_set:, filename:)
          @work.member_file_sets.find do |file_set|
            next false unless file_set.service_file

            attached_name = file_set.original_file&.original_filename.to_s
            next false unless attached_name == filename
            next false unless DerivativeLinkResolver.source_file_set_id_for(file_set) == source_file_set.id.to_s

            related_values = DerivativeLinkResolver.related_url_values_for(file_set)
            related_values.include?("#{THUMBNAIL_DERIVATIVE_PREFIX}#{DERIVATIVE_TYPE_PRESENTATION_VERSION}")
          end
        rescue StandardError
          false
        end

        def cache_payload(source_file_set:, output_path:, filename:)
          cache_file_identifier = cache_file_identifier_for(source_file_set_id: source_file_set.id, filename: filename)
          DerivativeCacheService.instance.store_derivative_from_path(
            file_identifier: cache_file_identifier,
            original_filename: filename,
            source_path: output_path,
            derivative_type: DERIVATIVE_TYPE_PRESENTATION_VERSION
          )

          {
            source_file_set_id: source_file_set.id.to_s,
            cache_file_identifier: cache_file_identifier,
            cache_filename: filename
          }
        end

        def cache_file_identifier_for(source_file_set_id:, filename:)
          "derivatives:presentation_version:work:#{@work.id}:source:#{source_file_set_id}:#{filename}"
        end

        def depositor
          @depositor ||= User.find_by(email: @work.depositor)
        end
      end
    end
  end
end