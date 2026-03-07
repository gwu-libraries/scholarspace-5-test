# frozen_string_literal: true

require 'whisper'

module CustomDerivativesServices
  class AudioTranscriptDerivativesService
    def initialize(work)
      @work = work
      @working_dir = nil
      @vtt_path = nil
    end

    def call
      prepare_working_directory
      copy_av_files_to_working_dir
      Dir.glob("#{@working_dir}/av_files/*").each do |file_path|
        generate_vtt(file_path)
      end
    end

    def prepare_working_directory
      dir_name = Time.now.to_i.to_s
      @working_dir = Rails.root.join('tmp', dir_name)

      Dir.mkdir(@working_dir)
      Dir.mkdir("#{@working_dir}/av_files")
      Dir.mkdir("#{@working_dir}/transcripts")
    end

    def cleanup_working_directory
      FileUtils.rm_rf(@working_dir)
    end

    def member_file_sets
      @work.member_ids.map { |id| Hyrax.query_service.find_by(id: id) }
    end

    def av_file_sets
      member_file_sets.select { |fs| fs.original_file.mime_type.start_with?('audio/', 'video/') }
    end

    def copy_av_files_to_working_dir
      av_file_sets.each_with_index do |fs, _i|
        io = Hyrax.storage_adapter.find_by(id: fs.original_file.file_identifier)
        destination_io = File.open("#{@working_dir}/av_files/#{fs.original_file.original_filename}", 'w')

        IO.copy_stream(io.stream, destination_io)
        destination_io.close
      end
    end

    def generate_vtt(file_path)
      # get the last part of the file path
      title = file_path.split('/').last.split('.').first

      whisper = Whisper::Context.new('base')

      vtt = whisper.transcribe(file_path, Whisper::Params.new).to_webvtt

      File.open("#{@working_dir}/transcripts/#{title}.vtt", 'w') do |file|
        file.write(vtt)
      end
    end
  end
end
