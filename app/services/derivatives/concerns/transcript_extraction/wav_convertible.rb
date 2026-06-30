# frozen_string_literal: true

require 'open3'

module Derivatives
  module Concerns
    module TranscriptExtraction
      module WavConvertible

    # method for creating a wav file

    private
  end

    def transcription_source_path(file_path)
      return file_path if File.extname(file_path).casecmp('.wav').zero?

      convert_to_wav(file_path)
    end

    def convert_to_wav(file_path)
      output_path = "#{File.dirname(file_path)}/#{File.basename(file_path, File.extname(file_path))}_whisper.wav"

      _stdout, stderr, status = Open3.capture3(
        'ffmpeg',
        '-y',
        '-i',
        file_path,
        '-vn',
        '-acodec',
        'pcm_s16le',
        '-ar',
        '16000',
        '-ac',
        '1',
        output_path
      )

      return output_path if status.success? && File.exist?(output_path)

      raise "Failed to convert #{file_path} to WAV: #{stderr}"
    end
    end
  end
end
