# frozen_string_literal: true

require 'fileutils'
require 'whisper'

module Derivatives
  module Concerns
    module TranscriptExtraction
      module VttGeneratable
      include FileOperations

      private
  end

      def generate_vtt(file_path, output_dir:, title: File.basename(file_path, File.extname(file_path)))
        configure_whisper_cache_dir
        whisper = Whisper::Context.new('base')
        vtt = whisper.transcribe(file_path, Whisper::Params.new).to_webvtt

        vtt_path = "#{output_dir}/#{title}_VTT.vtt"
        File.open(vtt_path, 'w') { |file| file.write(vtt) }
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
end
