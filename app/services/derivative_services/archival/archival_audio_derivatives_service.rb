# frozen_string_literal: true

require 'whisper'

module DerivativeServices
  module Archival
    class ArchivalAudioDerivativesService
      def initialize(work)
        @work = work

        @working_dir = nil
      end

      def create_derivatives
        prepare_working_dir

        if audio_file_sets.present?
          copy_audio_files_to_working_dir
          Dir.glob(File.join(@working_dir, 'audio', '*')).each do |audio_path|
            convert_audio_to_wav_file(audio_path)
            generate_audio_transcript(audio_path)
          end

          Dir.glob(File.join(@working_dir, 'transcript', '*')).each do |transcript_path|
            attach_transcript_to_work(transcript_path)
          end
        end
        cleanup_working_dir
      end

      private

      def prepare_working_dir
        dir_name = Time.now.to_i.to_s # just using timestamp for naming unique temp directory
        Dir.mkdir(Rails.root.join('tmp', dir_name))
        Dir.mkdir(Rails.root.join('tmp', dir_name, 'audio'))
        Dir.mkdir(Rails.root.join('tmp', dir_name, 'transcript'))
        @working_dir = Rails.root.join('tmp', dir_name)
      end

      def member_file_sets
        @work.member_ids.map { |id| Hyrax.query_service.find_by(id: id) }
      end

      def audio_file_sets
        member_file_sets.select { |fs| fs.original_file.mime_type.start_with?('audio/') }
      end

      def copy_audio_files_to_working_dir
        audio_file_sets.each_with_index do |fs, _i|
          io = Hyrax.storage_adapter.find_by(id: fs.original_file.file_identifier)
          destination_io = File.open("#{@working_dir}/audio/#{fs.original_file.original_filename}", 'w')

          IO.copy_stream(io.stream, destination_io)
          destination_io.close
        end
      end

      def convert_audio_to_wav_file(_audio_file)
        # cmd = "magick convert #{@working_dir}/images/* #{@image_joined_pdf_path}"

        # `#{cmd}`
      end

      def generate_audio_transcript(audio_file)
        title = @work.title&.first&.gsub(/\s+/, '_') || @work.id

        whisper = Whisper::Context.new('base')

        vtt = whisper.transcribe(audio_file, Whisper::Params.new).to_webvtt

        File.open("#{@working_dir}/transcript/#{title}.vtt", 'w') do |file|
          file.write(vtt)
        end
      end

      def attach_transcript_to_work(transcript_path)
        user = User.find_by(email: @work.depositor)
        return unless File.exist?(transcript_path) && user

        title = @work.title&.first&.gsub(/\s+/, '_') || @work.id
        filename = "#{title}.vtt"

        # Create and persist the FileSet first to ensure it has a stable id
        file_set = Hyrax::FileSet.new(title: [filename], label: filename)
        file_set = Hyrax.persister.save(resource: file_set)

        begin
          file_io = File.open(transcript_path, 'rb')

          Hyrax::ValkyrieUpload.file(
            filename: filename,
            file_set: file_set,
            io: file_io,
            user: user,
            mime_type: 'text/vtt',
            skip_derivatives: true
          )

          @work.member_ids << file_set.id
          Hyrax.persister.save(resource: @work)
          Hyrax.index_adapter.save(resource: file_set)
          Hyrax.index_adapter.save(resource: @work)
        ensure
          file_io&.close
        end
      end

      def cleanup_working_dir
        FileUtils.rm_rf(@working_dir)
      end
    end
  end
end
