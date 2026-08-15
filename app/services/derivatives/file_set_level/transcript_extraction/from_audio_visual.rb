# frozen_string_literal: true

module Derivatives
  module FileSetLevel
    module TranscriptExtraction
      # Entry point for transcript extraction from source audio/video files.
      class FromAudioVisual
        include ::Constants::DerivativeTypeConstants
        include ::Constants::MimeTypeConstants
        include Concerns::FileSetAttachable
        include Derivatives::Concerns::SourceFileSetMimeDetection
        include Concerns::TranscriptExtraction::VttGeneratable
        include Concerns::TranscriptExtraction::WavConvertible
        include FileOperations
        include PersistenceAdapter

        def initialize(work)
          @work = work
        end

        def source_file_set_ids
          audio_visual_file_sets.map { |file_set| file_set.id.to_s }
        end

        def generate_to_cache(source_file_set_id:)
          return unless depositor

          source_file_set = source_file_set_for(source_file_set_id)
          return unless source_file_set

          Dir.mktmpdir("audio_transcript_source_#{@work.id}_") do |dir|
            prepare_working_directory(dir)

            source_path = copy_single_audio_visual_to_working_dir(source_file_set)
            title = transcript_title_for_source_file_set(source_file_set)
            transcription_source = transcription_source_path(source_path)
            vtt_path = generate_vtt(transcription_source, output_dir: "#{dir}/transcripts", title: title)
            return nil unless vtt_path && File.exist?(vtt_path)

            cache_filename = File.basename(vtt_path)
            cache_file_identifier = cache_file_identifier_for(
              source_file_set_id: source_file_set.id,
              filename: cache_filename
            )

            DerivativeCacheService.instance.store_derivative_from_path(
              file_identifier: cache_file_identifier,
              original_filename: cache_filename,
              source_path: vtt_path,
              derivative_type: DERIVATIVE_TYPE_TRANSCRIPT
            )

            {
              source_file_set_id: source_file_set.id.to_s,
              cache_file_identifier: cache_file_identifier,
              cache_filename: cache_filename
            }
          end
        end

        def persist_from_cache(source_file_set_id:, cache_file_identifier:, cache_filename:)
          return unless depositor

          source_file_set = source_file_set_for(source_file_set_id)
          return unless source_file_set

          Dir.mktmpdir("audio_transcript_persist_#{@work.id}_") do |dir|
            cached_io = DerivativeCacheService.instance.fetch_stream(
              file_identifier: cache_file_identifier,
              original_filename: cache_filename
            )
            return unless cached_io

            transcript_path = File.join(dir, cache_filename)
            File.open(transcript_path, 'wb') { |io| IO.copy_stream(cached_io, io) }
            attach_vtt_to_work(transcript_path, source_file_set: source_file_set)
          ensure
            cached_io&.close
          end
        end

        private

        def prepare_working_directory(dir)
          @working_dir = dir
          ensure_directory_exists("#{dir}/audio_visual_files")
          ensure_directory_exists("#{dir}/transcripts")
        end

        def transcript_title_for(file_path)
          File.basename(file_path, File.extname(file_path))
        end

        def transcript_title_for_source_file_set(file_set)
          filename = file_set.original_file&.original_filename.to_s
          title = transcript_title_for(filename)
          return title if title.present?

          file_set.id.to_s
        end

        def audio_visual_file_sets
          @work.member_file_sets.select do |file_set|
            !file_set.service_file && source_audio_visual_file_set?(file_set)
          end
        end

        def source_file_set_for(source_file_set_id)
          audio_visual_file_sets.find { |file_set| file_set.id.to_s == source_file_set_id.to_s }
        end

        def copy_single_audio_visual_to_working_dir(file_set)
          filename = file_set.original_file&.original_filename.to_s
          extension = File.extname(filename)
          extension = '.bin' if extension.blank?
          destination_path = "#{@working_dir}/audio_visual_files/#{file_set.id}#{extension}"
          copy_file_to_disk(file_set.original_file.file_identifier, destination_path)
        end

        def depositor
          @depositor ||= User.find_by(email: @work.depositor)
        end

        def transcript_file_set(filename, source_file_set:)
          @work.member_file_sets.find do |file_set|
            attached_name = file_set.original_file&.original_filename.to_s
            attached_title = file_set.title.to_a.join(' ')
            name_matches = attached_name == filename || attached_title == filename
            next false unless name_matches

            DerivativeLinkResolver.source_file_set_id_for(file_set) == source_file_set.id.to_s
          end
        end

        def attach_vtt_to_work(vtt_path, source_file_set:)
          return unless File.exist?(vtt_path) && depositor

          filename = File.basename(vtt_path)
          existing = transcript_file_set(filename, source_file_set: source_file_set)
          if existing
            refreshed_file_set = replace_file_set_file(file_set: existing, file_path: vtt_path, user: depositor)
            update_work_rendering_ids(refreshed_file_set || existing)
            return
          end

          file_set = attach_single_file_to_work(file_path: vtt_path, user: depositor, service_file: true,
                                                source_file_set: source_file_set)
          ensure_source_linkage!(file_set: file_set, source_file_set: source_file_set)
          update_work_rendering_ids(file_set)
        end

        def ensure_source_linkage!(file_set:, source_file_set:)
          return unless file_set && source_file_set

          linked_source_id = DerivativeLinkResolver.source_file_set_id_for(file_set)
          return if linked_source_id == source_file_set.id.to_s

          raise "Transcript derivative missing source linkage: file_set=#{file_set.id} source=#{source_file_set.id}"
        end

        def update_work_rendering_ids(file_set)
          attached_file_set_id = file_set&.id&.to_s
          return if attached_file_set_id.blank?

          with_work_lock do
            work = reload_work
            return unless work

            existing_rendering_ids = Array(work.rendering_ids).map(&:to_s)
            merged_rendering_ids = (existing_rendering_ids + [attached_file_set_id]).uniq
            return if merged_rendering_ids == existing_rendering_ids

            work.rendering_ids = merged_rendering_ids
            @work = save_and_index(work)
          end
        end

        def cache_file_identifier_for(source_file_set_id:, filename:)
          "derivatives:audio_transcript:work:#{@work.id}:source:#{source_file_set_id}:#{filename}"
        end
      end
    end
  end
end
