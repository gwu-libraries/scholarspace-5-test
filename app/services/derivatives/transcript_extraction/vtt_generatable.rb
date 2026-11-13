# frozen_string_literal: true

require 'fileutils'
require 'whisper'

module Derivatives::TranscriptExtraction
  module VttGeneratable
    include FileOperations

    private

    def generate_vtt(file_path, output_dir:, title: File.basename(file_path, File.extname(file_path)))
      configure_whisper_cache_dir
      whisper = Whisper::Context.new(Configuration::DerivativeSettings.transcription_model)
      vtt = whisper.transcribe(file_path, Whisper::Params.new).to_webvtt
      # Whisper's native UTF-8 output can be tagged as ASCII-8BIT.
      vtt = vtt.dup.force_encoding(Encoding::UTF_8) if vtt.encoding == Encoding::ASCII_8BIT
      vtt = vtt.encode(Encoding::UTF_8)
      raise Encoding::InvalidByteSequenceError, 'Whisper returned invalid UTF-8 WebVTT' unless vtt.valid_encoding?

      vtt_path = "#{output_dir}/#{title}_VTT.vtt"
      File.open(vtt_path, 'w:UTF-8') { |file| file.write(vtt) }
      vtt_path
    end

    def configure_whisper_cache_dir
      cache_root = '/app/scholarspace/tmp/cache/whispercpp'
      ensure_directory_exists(cache_root)
      ENV['XDG_CACHE_HOME'] = if File.writable?(cache_root)
                                cache_root
                              else
                                fallback = ENV.fetch('WHISPER_CACHE_ROOT', '/tmp/scholarspace-cache/whispercpp')
                                ensure_directory_exists(fallback)
                                fallback
                              end
    rescue SystemCallError
      fallback = ENV.fetch('WHISPER_CACHE_ROOT', '/tmp/scholarspace-cache/whispercpp')
      ensure_directory_exists(fallback)
      ENV['XDG_CACHE_HOME'] = fallback
end
  end
end
