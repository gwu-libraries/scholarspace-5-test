# frozen_string_literal: true

require 'open3'

module Derivatives
  module FileSetLevel
    class PresentationVersion
    include ::DerivativeTypeConstants
    include ::FileExtensionConstants
    include ::MimeTypeConstants
    include Concerns::FileSetAttachable
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

    def self.source_image_file_set_ids(work)
      new(work).source_image_file_sets.map { |file_set| file_set.id.to_s }
    end

    def self.source_av_file_set_ids(work)
      new(work).source_av_file_sets.map { |file_set| file_set.id.to_s }
    end

    def generate_image_presentation_to_cache(source_file_set_id:)
      source_file_set = source_image_file_sets.find { |file_set| file_set.id.to_s == source_file_set_id.to_s }
      return unless source_file_set
      return unless depositor

      Dir.mktmpdir("presentation_image_#{@work.id}_") do |dir|
        source_path = copy_source_to_path(source_file_set, dir: dir)
        output_extension = image_output_extension(source_file_set)
        filename = presentation_filename(source_file_set, extension: output_extension)
        output_path = File.join(dir, filename)

        build_image_presentation(source_path: source_path, output_path: output_path)
        return nil unless File.exist?(output_path)

        cache_payload(source_file_set: source_file_set, output_path: output_path, filename: filename)
      end
    end

    def persist_image_presentation_from_cache(source_file_set_id:, cache_file_identifier:, cache_filename:)
      source_file_set = source_image_file_sets.find { |file_set| file_set.id.to_s == source_file_set_id.to_s }
      persist_from_cache(
        source_file_set: source_file_set,
        cache_file_identifier: cache_file_identifier,
        cache_filename: cache_filename
      )
    end

    def generate_av_presentation_to_cache(source_file_set_id:)
      source_file_set = source_av_file_sets.find { |file_set| file_set.id.to_s == source_file_set_id.to_s }
      return unless source_file_set
      return unless depositor

      Dir.mktmpdir("presentation_av_#{@work.id}_") do |dir|
        source_path = copy_source_to_path(source_file_set, dir: dir)
        output_extension = av_output_extension(source_file_set)
        filename = presentation_filename(source_file_set, extension: output_extension)
        output_path = File.join(dir, filename)

        build_av_presentation(source_path: source_path, output_path: output_path, source_file_set: source_file_set)
        return nil unless File.exist?(output_path)

        cache_payload(source_file_set: source_file_set, output_path: output_path, filename: filename)
      end
    end

    def persist_av_presentation_from_cache(source_file_set_id:, cache_file_identifier:, cache_filename:)
      source_file_set = source_av_file_sets.find { |file_set| file_set.id.to_s == source_file_set_id.to_s }
      persist_from_cache(
        source_file_set: source_file_set,
        cache_file_identifier: cache_file_identifier,
        cache_filename: cache_filename
      )
    end

    private

    def source_image_file_sets
      @work.member_file_sets.select do |file_set|
        !file_set.service_file && file_set.original_file&.mime_type.to_s.start_with?(IMAGE_MIME_PREFIX)
      end
    end

    def source_av_file_sets
      @work.member_file_sets.select do |file_set|
        !file_set.service_file && file_set.original_file&.mime_type.to_s.start_with?(*AUDIO_VIDEO_MIME_PREFIXES)
      end
    end

    def copy_source_to_path(source_file_set, dir:)
      original_filename = source_file_set.original_file&.original_filename.to_s
      extension = File.extname(original_filename)
      extension = '.bin' if extension.blank?
      source_path = File.join(dir, "#{source_file_set.id}#{extension}")
      copy_file_to_disk(source_file_set.original_file.file_identifier, source_path)
      source_path
    end

    def image_output_extension(source_file_set)
      original_ext = File.extname(source_file_set.original_file&.original_filename.to_s).downcase
      IMAGE_EXTENSIONS_FOR_PRESENTATION.fetch(original_ext, '.jpg')
    end

    def av_output_extension(source_file_set)
      mime_type = source_file_set.original_file&.mime_type.to_s
      return '.mp4' if mime_type.start_with?(VIDEO_MIME_PREFIX)

      '.mp3'
    end

    def presentation_filename(source_file_set, extension:)
      original_filename = source_file_set.original_file&.original_filename.to_s
      base_name = File.basename(original_filename, File.extname(original_filename))
      "#{base_name}#{PRESENTATION_VERSION_FILENAME_STEM}#{extension}"
    end

    def build_image_presentation(source_path:, output_path:)
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

    def build_av_presentation(source_path:, output_path:, source_file_set:)
      mime_type = source_file_set.original_file&.mime_type.to_s
      cmd = if mime_type.start_with?(VIDEO_MIME_PREFIX)
              [
                'ffmpeg', '-y', '-i', source_path,
                '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '28',
                '-c:a', 'aac', '-b:a', '128k',
                '-movflags', '+faststart',
                output_path
              ]
            else
              [
                'ffmpeg', '-y', '-i', source_path,
                '-vn', '-c:a', 'libmp3lame', '-q:a', '5',
                output_path
              ]
            end

      _stdout, stderr, status = Open3.capture3(*cmd)
      return if status.success?

      raise "Unable to create AV presentation version: #{stderr.to_s.strip.truncate(300)}"
    end

    def persist_from_cache(source_file_set:, cache_file_identifier:, cache_filename:)
      return unless source_file_set
      return unless depositor
      return if linked_presentation_already_attached?(source_file_set: source_file_set, filename: cache_filename)

      Dir.mktmpdir("presentation_persist_#{@work.id}_") do |dir|
        cached_io = DerivativeCacheService.instance.fetch_stream(
          file_identifier: cache_file_identifier,
          original_filename: cache_filename
        )
        return unless cached_io

        output_path = File.join(dir, cache_filename)
        File.open(output_path, 'wb') { |io| IO.copy_stream(cached_io, io) }

        attach_single_file_to_work(
          file_path: output_path,
          user: depositor,
          service_file: true,
          source_file_set: source_file_set,
          derivative_type_override: DERIVATIVE_TYPE_PRESENTATION_VERSION
        )
      ensure
        cached_io&.close
      end
    end

    def linked_presentation_already_attached?(source_file_set:, filename:)
      @work.member_file_sets.any? do |file_set|
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
