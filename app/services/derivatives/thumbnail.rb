# frozen_string_literal: true

require 'fileutils'

module Derivatives
  class Thumbnail
    include Concerns::FileSetAttachable
    include Concerns::ThumbnailGeneratable
    include FileOperations
    include FileSetDerivativeMetadata
    include PersistenceAdapter
    include StringNormalization

    REPRESENTATIVE_THUMBNAIL_FILENAME = 'REPRESENTATIVE_THUMBNAIL.jpg'

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

    private

    def source_file_sets
      @work.original_member_file_sets
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

    def generate_thumbnail_asset(source_file_set, thumbnail_filename)
      source_path = copy_source_to_working_dir(source_file_set)
      return nil unless source_path

      output_path = File.join(@working_dir, thumbnail_filename)
      generate_thumbnail_file(
        source_path: source_path,
        output_thumbnail_path: output_path,
        mime_type: source_file_set.original_file&.mime_type.to_s,
        error_message: "Unable to generate thumbnail for file set #{source_file_set.id}"
      )
      output_path
    end

    # is the fileset an image, video, or pdf?
    def thumbnail_supported?(file_set)
      if file_set.respond_to?(:image?) && file_set.respond_to?(:video?) && file_set.respond_to?(:pdf?)
        file_set.image? || file_set.video? || file_set.pdf?
      else
        mime_type = file_set.original_file&.mime_type.to_s
        mime_type.start_with?('image/', 'video/') || mime_type == 'application/pdf'
      end
    end

    def copy_source_to_working_dir(file_set)
      original_file = file_set.original_file
      return nil unless original_file&.file_identifier

      extension = File.extname(original_file.original_filename.to_s)
      extension = '.bin' if extension.blank?
      source_path = File.join(@working_dir, "#{file_set.id}#{extension}")

      copy_file_to_disk(original_file.file_identifier, source_path)
    end

    def thumbnail_filename_for(file_set)
      original_filename = file_set.original_file&.original_filename.to_s
      stem = File.basename(original_filename, File.extname(original_filename))
      sanitized = stem.gsub(/[^0-9A-Za-z.-]+/, '_').gsub(/\A_+|_+\z/, '')
      sanitized = 'source' if sanitized.blank?
      "#{sanitized}_THUMBNAIL.jpg"
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
      @work.member_file_sets.find do |file_set|
        thumbnail_service_file_set?(file_set) && representative_thumbnail_tagged_for_work?(file_set)
      end
    end

    def best_representative_candidate(derivative_candidates)
      derivative_candidates.min_by do |candidate|
        source_file_set = candidate.fetch(:source_file_set)
        [representative_priority_for(source_file_set), representative_sort_name_for(source_file_set)]
      end
    end

    def representative_sort_name_for(file_set)
      file_set
        .original_file
        &.original_filename
        .to_s
        .downcase
    end

    def representative_priority_for(file_set)
      mime_type = normalize_mime_type(file_set.original_file&.mime_type)
      return 0 if mime_type.start_with?('image/')
      return 1 if mime_type == 'application/pdf'
      return 2 if mime_type.start_with?('audio/', 'video/')

      99
    end

    def work_thumbnail_file_set
      return nil unless @work.respond_to?(:thumbnail_id) && @work.thumbnail_id.present?

      @work.member_file_sets.find { |file_set| file_set.id.to_s == @work.thumbnail_id.to_s }
    end

    def thumbnail_service_file_set?(file_set)
      return false unless file_set&.respond_to?(:service_file) && file_set.service_file

      return true if tags_for_file_set(file_set).include?('derivative_type:thumbnail')

      mime_type = normalize_mime_type(file_set.original_file&.mime_type)
      original_filename = normalize_filename(file_set.original_file&.original_filename)
      title = file_set.respond_to?(:title) ? normalize_string(file_set.title.to_a.join(' ')) : ''

      return false unless mime_type.start_with?('image/')

      original_filename.include?('_thumbnail.') || title.include?('_thumbnail.')
    end

    def representative_thumbnail_tag
      "representative_thumbnail_for_work:#{@work.id}"
    end

    def representative_thumbnail_tagged_for_work?(file_set)
      tags_for_file_set(file_set).include?(representative_thumbnail_tag)
    end

    def tag_as_representative_thumbnail(file_set)
      return nil unless file_set

      @work.member_file_sets.each do |fs|
        next if fs.id.to_s == file_set.id.to_s
        next unless representative_thumbnail_tagged_for_work?(fs)

        remove_tag_from_file_set(fs, representative_thumbnail_tag)
      end

      add_tag_to_file_set(file_set, representative_thumbnail_tag)
    end

    def depositor
      @depositor ||= User.find_by(email: @work.depositor)
    end

    def set_work_thumbnail(representative_thumbnail_id:)
      with_work_lock do
        work = reload_work
        return unless work&.respond_to?(:thumbnail_id=)

        work.thumbnail_id = representative_thumbnail_id
        @work = save_and_index(work)
      end
    end
  end
end
