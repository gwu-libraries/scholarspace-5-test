# frozen_string_literal: true

require 'fileutils'

module ScholarspaceDerivativesServices
  class ThumbnailDerivativesService
    include Concerns::FileSetAttachable
    include Concerns::ThumbnailGeneratable

    REPRESENTATIVE_THUMBNAIL_FILENAME = 'REPRESENTATIVE_THUMBNAIL.jpg'

    def initialize(work)
      @work = work
    end

    def call
      return if source_file_sets.empty?
      return unless depositor

      Dir.mktmpdir("thumbnail_derivatives_#{@work.id}_") do |dir|
        @working_dir = dir
        first_derivative_thumbnail = nil

        source_file_sets.each do |source_file_set|
          next unless thumbnail_supported?(source_file_set)

          thumbnail_filename = thumbnail_filename_for(source_file_set)
          attached_file_set = find_service_file_set_by_filename(thumbnail_filename)

          if attached_file_set.nil?
            source_path = copy_source_to_working_dir(source_file_set)
            next unless source_path

            output_thumbnail_path = File.join(@working_dir, thumbnail_filename)
            generate_thumbnail_file(
              source_path: source_path,
              output_thumbnail_path: output_thumbnail_path,
              mime_type: source_file_set.original_file&.mime_type.to_s,
              error_message: "Unable to generate thumbnail for file set #{source_file_set.id}"
            )

            attached_file_set = attach_single_file_to_work(
              file_path: output_thumbnail_path,
              user: depositor,
              service_file: true,
              source_file_set: source_file_set
            )
          end

          first_derivative_thumbnail ||= attached_file_set
        end

        representative_thumbnail = ensure_representative_thumbnail(first_derivative_thumbnail: first_derivative_thumbnail)
        set_work_thumbnail(representative_thumbnail_id: representative_thumbnail&.id) if representative_thumbnail
      end
    rescue StandardError => e
      Rails.logger.error("ThumbnailDerivativesService failed for work #{@work.id}: #{e.class} #{e.message}")
      raise
    end

    private

    # prevent generating derivatives for derivatives recursively
    def source_file_sets
      member_file_sets.reject(&:service_file)
    end

    # is the fileset an image, video, or pdf?
    def thumbnail_supported?(file_set)
      mime_type = file_set.original_file&.mime_type.to_s
      mime_type.start_with?('image/', 'video/') || mime_type == 'application/pdf'
    end

    def copy_source_to_working_dir(file_set)
      original_file = file_set.original_file
      return nil unless original_file&.file_identifier

      extension = File.extname(original_file.original_filename.to_s)
      extension = '.bin' if extension.blank?
      source_path = File.join(@working_dir, "#{file_set.id}#{extension}")
      io = Hyrax.storage_adapter.find_by(id: original_file.file_identifier)

      File.open(source_path, 'wb') do |destination_io|
        IO.copy_stream(io.stream, destination_io)
      end

      source_path
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

      member_file_sets.find do |file_set|
        next false unless file_set.respond_to?(:service_file) && file_set.service_file

        attached_name = file_set.original_file&.original_filename.to_s
        attached_title = file_set.title.to_a.join(' ')
        attached_name == filename || attached_title == filename
      end
    end

    def ensure_representative_thumbnail(first_derivative_thumbnail:)
      return nil unless first_derivative_thumbnail

      existing_representative = find_service_file_set_by_filename(REPRESENTATIVE_THUMBNAIL_FILENAME)
      return existing_representative if existing_representative

      source_path = copy_source_to_working_dir(first_derivative_thumbnail)
      return nil unless source_path

      output_path = File.join(@working_dir, REPRESENTATIVE_THUMBNAIL_FILENAME)
      FileUtils.cp(source_path, output_path)

      attach_single_file_to_work(
        file_path: output_path,
        user: depositor,
        service_file: true,
        source_file_set: first_derivative_thumbnail
      )
    end

    def depositor
      @depositor ||= User.find_by(email: @work.depositor)
    end

    def set_work_thumbnail(representative_thumbnail_id:)
      with_work_lock do
        work = reload_work
        return unless work&.respond_to?(:thumbnail_id=)

        work.thumbnail_id = representative_thumbnail_id
        @work = Hyrax.persister.save(resource: work)
        Hyrax.index_adapter.save(resource: @work)
      end
    end
  end
end
