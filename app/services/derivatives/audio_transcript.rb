# frozen_string_literal: true

module Derivatives
  class AudioTranscript
    include Concerns::FileSetAttachable
    include Concerns::VttGeneratable
    include Concerns::WavConvertible
    include FileOperations
    include PersistenceAdapter

    def initialize(work)
      @work = work
    end

    def call
      Dir.mktmpdir("audio_transcript_#{@work.id}_") do |dir|
        prepare_working_directory(dir)
        copy_av_files_to_working_dir.each do |av_file|
          generate_and_attach_transcript(av_file, dir)
        end
      end
    end

    def prepare_working_directory(dir)
      @working_dir = dir
      ensure_directory_exists("#{dir}/av_files")
      ensure_directory_exists("#{dir}/transcripts")
    end

    def generate_and_attach_transcript(av_file, dir)
      file_path = av_file[:path]
      title = transcript_title_for(file_path)
      transcription_source = transcription_source_path(file_path)
      vtt_path = generate_vtt(transcription_source, output_dir: "#{dir}/transcripts", title: title)
      attach_vtt_to_work(vtt_path, source_file_set: av_file[:file_set])
    end

    def transcript_title_for(file_path)
      File.basename(file_path, File.extname(file_path))
    end

    def av_file_sets
      @work.member_file_sets.select do |file_set|
        !file_set.service_file && file_set.original_file&.mime_type.to_s.start_with?('audio/', 'video/')
      end
    end

    def copy_av_files_to_working_dir
      av_file_sets.map do |fs|
        destination_path = "#{@working_dir}/av_files/#{fs.original_file.original_filename}"
        copy_file_to_disk(fs.original_file.file_identifier, destination_path)

        { file_set: fs, path: destination_path }
      end
    end

    def depositor
      @depositor ||= User.find_by(email: @work.depositor)
    end

    def transcript_already_attached?(filename, source_file_set:)
      @work.member_file_sets.any? do |file_set|
        attached_name = file_set.original_file&.original_filename.to_s
        attached_title = file_set.title.to_a.join(' ')
        name_matches = attached_name == filename || attached_title == filename
        next false unless name_matches

        source_tag = Array(file_set.related_url).map(&:to_s).find { |v| v.start_with?('source_file_set_id:') }
        source_tag == "source_file_set_id:#{source_file_set.id}"
      end
    end

    def attach_vtt_to_work(vtt_path, source_file_set:)
      return unless File.exist?(vtt_path) && depositor

      filename = File.basename(vtt_path)
      return if transcript_already_attached?(filename, source_file_set: source_file_set)

      file_set = attach_single_file_to_work(file_path: vtt_path, user: depositor, service_file: true,
                                            source_file_set: source_file_set)
      update_work_rendering_ids(file_set)
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
  end
end
