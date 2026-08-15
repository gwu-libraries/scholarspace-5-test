# frozen_string_literal: true

module Derivatives
  module FileSetLevel
    module ThumbnailCreation
      # File-set thumbnail creation entrypoint used by file_set_level jobs.
      class Thumbnail
        include ::Constants::DerivativeTypeConstants
        include Concerns::FileSetAttachable

        def self.thumbnail_supported_file_set?(file_set)
          generator_class_for(file_set).present?
        end

        def initialize(work)
          @work = work
        end

        def generate_to_cache(source_file_set_id:)
          return unless depositor

          source_file_set = source_file_set_for(source_file_set_id)
          return unless source_file_set
          return unless thumbnail_supported?(source_file_set)

          Dir.mktmpdir("thumbnail_derivative_source_#{@work.id}_") do |dir|
            @working_dir = dir
            thumbnail_filename = thumbnail_filename_for(source_file_set)
            output_path = generate_thumbnail_asset(source_file_set, thumbnail_filename)
            return nil unless output_path && File.exist?(output_path)

            cache_file_identifier = cache_file_identifier_for(
              source_file_set_id: source_file_set.id,
              filename: thumbnail_filename
            )

            DerivativeCacheService.instance.store_derivative_from_path(
              file_identifier: cache_file_identifier,
              original_filename: thumbnail_filename,
              source_path: output_path,
              derivative_type: DERIVATIVE_TYPE_THUMBNAIL
            )

            {
              source_file_set_id: source_file_set.id.to_s,
              cache_file_identifier: cache_file_identifier,
              cache_filename: thumbnail_filename
            }
          end
        rescue StandardError => e
          Rails.logger.error(
            "Thumbnail source cache job failed for work #{@work.id}, source #{source_file_set_id}: " \
            "#{e.class} #{e.message}"
          )
          raise
        end

        def persist_from_cache(source_file_set_id:, cache_file_identifier:, cache_filename:)
          return unless depositor

          source_file_set = source_file_set_for(source_file_set_id)
          return unless source_file_set
          return unless thumbnail_supported?(source_file_set)

          Dir.mktmpdir("thumbnail_persist_#{@work.id}_") do |dir|
            @working_dir = dir
            cached_io = DerivativeCacheService.instance.fetch_stream(
              file_identifier: cache_file_identifier,
              original_filename: cache_filename
            )
            return unless cached_io

            output_path = File.join(@working_dir, cache_filename)
            File.open(output_path, 'wb') { |io| IO.copy_stream(cached_io, io) }

            existing = find_service_file_set_by_filename(cache_filename)
            if existing
              update_file_set_file(existing, output_path)
            else
              attach_single_file_to_work(
                file_path: output_path,
                user: depositor,
                service_file: true,
                source_file_set: source_file_set
              )
            end
          ensure
            cached_io&.close
          end
        rescue StandardError => e
          Rails.logger.error(
            "Thumbnail persist failed for work #{@work.id}, source #{source_file_set_id}: " \
            "#{e.class} #{e.message}"
          )
          raise
        end

        private

        def depositor
          @depositor ||= User.find_by(email: @work.depositor)
        end

        def source_file_set_for(source_file_set_id)
          source_file_sets.find { |file_set| file_set.id.to_s == source_file_set_id.to_s }
        end

        def source_file_sets
          @work.original_member_file_sets
        end

        def generator_for(source_file_set)
          self.class.generator_class_for(source_file_set)&.new(@work, working_dir: @working_dir)
        end

        def thumbnail_filename_for(file_set)
          generator_for(file_set)&.thumbnail_filename_for(file_set)
        end

        def self.generator_class_for(file_set)
          return FromImage if FromImage.supported_file_set?(file_set)
          return FromPdf if FromPdf.supported_file_set?(file_set)
          return FromAudioVisual if FromAudioVisual.supported_file_set?(file_set)

          nil
        end

        def generate_thumbnail_asset(source_file_set, thumbnail_filename)
          generator = generator_for(source_file_set)
          return nil unless generator

          generator.generate_thumbnail_asset(source_file_set, thumbnail_filename)
        end

        def thumbnail_supported?(file_set)
          self.class.thumbnail_supported_file_set?(file_set)
        end

        def find_service_file_set_by_filename(filename)
          return nil if filename.blank?

          @work.member_file_sets.find do |file_set|
            next false unless file_set.respond_to?(:service_file) && file_set.service_file

            attached_name = file_set.original_file&.original_filename.to_s
            attached_title = file_set.title.to_a.join(' ')
            attached_name == filename || attached_title == filename
          end
        end

        def update_file_set_file(file_set, new_file_path)
          replace_file_set_file(file_set: file_set, file_path: new_file_path, user: depositor)
        end

        def cache_file_identifier_for(source_file_set_id:, filename:)
          "derivatives:thumbnail:work:#{@work.id}:source:#{source_file_set_id}:#{filename}"
        end
      end
    end
  end
end
