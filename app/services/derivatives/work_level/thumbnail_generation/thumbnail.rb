# frozen_string_literal: true

require 'fileutils'

module Derivatives
  module WorkLevel
    module ThumbnailGeneration
      class Thumbnail
      include ::Constants::ThumbnailTagConstants
      include Concerns::FileSetAttachable
      include FileOperations
      include ::FileSetDerivativeMetadata
      include PersistenceAdapter
      include StringNormalization
      include ::Constants::DerivativeTypeConstants
      include ::Constants::MimeTypeConstants
      include ::Constants::ThumbnailFilenameConstants

      def initialize(work)
        @work = work
      end

      def call
        return if source_file_sets.empty?
        return unless depositor

        Dir.mktmpdir("thumbnail_derivatives_#{@work.id}_") do |dir|
          @working_dir = dir

          generate_supported_thumbnails
          ensure_best_thumbnail_is_representative
        end
      rescue StandardError => e
        Rails.logger.error("Thumbnail failed for work #{@work.id}: #{e.class} #{e.message}")
        raise
      end

      def generate_for_source_file_set(source_file_set_id:)
        return unless depositor

        source_file_set = source_file_set_for(source_file_set_id)
        return unless source_file_set
        return unless thumbnail_supported?(source_file_set)

        Dir.mktmpdir("thumbnail_derivative_source_#{@work.id}_") do |dir|
          @working_dir = dir
          generate_thumbnail_for(source_file_set)
        end
      rescue StandardError => e
        Rails.logger.error("Thumbnail source job failed for work #{@work.id}, source #{source_file_set_id}: #{e.class} #{e.message}")
        raise
      end

      def generate_for_source_file_set_to_cache(source_file_set_id:)
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
        Rails.logger.error("Thumbnail source cache job failed for work #{@work.id}, source #{source_file_set_id}: #{e.class} #{e.message}")
        raise
      end

      def persist_thumbnail_from_cache(source_file_set_id:, cache_file_identifier:, cache_filename:)
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
        Rails.logger.error("Thumbnail persist failed for work #{@work.id}, source #{source_file_set_id}: #{e.class} #{e.message}")
        raise
      end

      def ensure_representative_thumbnail!
        return if source_file_sets.empty?
        return unless depositor

        Dir.mktmpdir("thumbnail_finalize_#{@work.id}_") do |dir|
          @working_dir = dir
          ensure_best_thumbnail_is_representative
        end
      rescue StandardError => e
        Rails.logger.error("Thumbnail finalize failed for work #{@work.id}: #{e.class} #{e.message}")
        raise
      end

      def self.thumbnail_supported_file_set?(file_set)
        self.generator_class_for(file_set).present?
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

      def copy_source_to_working_dir(file_set)
        generator_for(file_set)&.copy_source_to_working_dir(file_set)
      end

      def self.generator_class_for(file_set)
        return FileSetLevel::ThumbnailGeneration::FromImage if FileSetLevel::ThumbnailGeneration::FromImage.supported_file_set?(file_set)
        return FileSetLevel::ThumbnailGeneration::FromPdf if FileSetLevel::ThumbnailGeneration::FromPdf.supported_file_set?(file_set)
        return FileSetLevel::ThumbnailGeneration::FromAv if FileSetLevel::ThumbnailGeneration::FromAv.supported_file_set?(file_set)

        nil
      end

      def generate_supported_thumbnails
        source_file_sets.each do |source_file_set|
          next unless thumbnail_supported?(source_file_set)

          generate_thumbnail_for(source_file_set)
        end
      end

      def ensure_best_thumbnail_is_representative
        derivative_candidates = derivative_thumbnail_candidates
        return if derivative_candidates.empty?

        thumbnail_file_set = build_representative_thumbnail(derivative_candidates: derivative_candidates)
        return unless thumbnail_file_set

        current_thumbnail_id = @work.thumbnail_id.to_s
        return if current_thumbnail_id == thumbnail_file_set.id.to_s

        set_work_thumbnail(representative_thumbnail_id: thumbnail_file_set.id)
      end

      def derivative_thumbnail_candidates
        source_file_sets.filter_map do |source_file_set|
          next unless thumbnail_supported?(source_file_set)

          derivative_thumbnail = find_or_create_thumbnail_for(source_file_set)
          next unless derivative_thumbnail

          {
            source_file_set: source_file_set,
            derivative_thumbnail: derivative_thumbnail
          }
        end
      end

      def generate_thumbnail_for(source_file_set)
        thumbnail_filename = thumbnail_filename_for(source_file_set)
        output_path = generate_thumbnail_asset(source_file_set, thumbnail_filename)
        return unless output_path

        existing = find_service_file_set_by_filename(thumbnail_filename)
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
      end

      def find_or_create_thumbnail_for(source_file_set)
        thumbnail_filename = thumbnail_filename_for(source_file_set)
        existing = find_service_file_set_by_filename(thumbnail_filename)
        return existing if existing

        output_path = generate_thumbnail_asset(source_file_set, thumbnail_filename)
        return nil unless output_path

        attach_single_file_to_work(
          file_path: output_path,
          user: depositor,
          service_file: true,
          source_file_set: source_file_set
        )
      end

      def best_source_file_for_thumbnail
        source_file_sets.min_by { |fs| priority_for(fs) }
      end

      def priority_for(file_set)
        return 0 if file_set.respond_to?(:image?) && file_set.image?
        return 1 if file_set.respond_to?(:pdf?) && file_set.pdf?
        return 2 if (file_set.respond_to?(:audio?) && file_set.audio?) || (file_set.respond_to?(:video?) && file_set.video?)
        99
      end

      def update_file_set_file(file_set, new_file_path)
        file_set
      end

      def cache_file_identifier_for(source_file_set_id:, filename:)
        "derivatives:thumbnail:work:#{@work.id}:source:#{source_file_set_id}:#{filename}"
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

      def build_representative_thumbnail(derivative_candidates:)
        existing_representative = representative_thumbnail_file_set_by_metadata
        return existing_representative if existing_representative

        candidate = best_representative_candidate(derivative_candidates)
        return nil unless candidate

        source_file_set = candidate.fetch(:source_file_set)
        derivative_thumbnail = candidate.fetch(:derivative_thumbnail)
        source_path = copy_source_to_working_dir(derivative_thumbnail)
        return nil unless source_path

        output_path = File.join(@working_dir, REPRESENTATIVE_THUMBNAIL_FILENAME)
        FileUtils.cp(source_path, output_path)

        representative_thumbnail = attach_single_file_to_work(
          file_path: output_path,
          user: depositor,
          service_file: true,
          source_file_set: source_file_set
        )

        tag_as_representative_thumbnail(representative_thumbnail)
      end

      def representative_thumbnail_file_set_by_metadata
        nil
      end

      def best_representative_candidate(derivative_candidates)
        derivative_candidates.sort_by do |candidate|
          source_file_set = candidate.fetch(:source_file_set)

          [
            priority_for(source_file_set),
            normalize_filename(source_file_set.original_file&.original_filename.to_s)
          ]
        end.first
      end

      def tag_as_representative_thumbnail(file_set)
        file_set
      end
    end
  end
  end
end
