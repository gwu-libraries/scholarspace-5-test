# frozen_string_literal: true

module ScholarspaceDerivativesServices
  class AudioTranscriptDerivativesService
    include Concerns::FileSetAttachable
    include Concerns::VttGeneratable
    include Concerns::WavConvertible

    def initialize(work)
      @work = work
    end

    def call
      Dir.mktmpdir("audio_transcript_#{@work.id}_") do |dir|
        @working_dir = dir
        Dir.mkdir("#{dir}/av_files")
        Dir.mkdir("#{dir}/transcripts")
        copied_av_files = copy_av_files_to_working_dir
        copied_av_files.each do |av_file|
          file_path = av_file[:path]
          title = File.basename(file_path, File.extname(file_path))
          transcription_source = transcription_source_path(file_path)
          vtt_path = generate_vtt(transcription_source, output_dir: "#{dir}/transcripts", title: title)
          attach_vtt_to_work(vtt_path, source_file_set: av_file[:file_set])
        end
      end
    end

    def av_file_sets
      member_file_sets.select do |file_set|
        !file_set.service_file && file_set.original_file&.mime_type.to_s.start_with?('audio/', 'video/')
      end
    end

    def copy_av_files_to_working_dir
      av_file_sets.each_with_index.map do |fs, _i|
        io = Hyrax.storage_adapter.find_by(id: fs.original_file.file_identifier)
        destination_path = "#{@working_dir}/av_files/#{fs.original_file.original_filename}"
        destination_io = File.open(destination_path, 'wb')

        IO.copy_stream(io.stream, destination_io)
        destination_io.close

        { file_set: fs, path: destination_path }
      end
    end

    def depositor
      @depositor ||= User.find_by(email: @work.depositor)
    end

    def transcript_already_attached?(filename)
      file_set_attached_with_name?(filename)
    end

    def attach_vtt_to_work(vtt_path, source_file_set:)
      return unless File.exist?(vtt_path) && depositor

      filename = File.basename(vtt_path)
      return if transcript_already_attached?(filename)

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
        @work = Hyrax.persister.save(resource: work)
        Hyrax.index_adapter.save(resource: @work)
      end
    end
  end
end
