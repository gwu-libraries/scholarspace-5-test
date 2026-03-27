# frozen_string_literal: true

require 'fileutils'
require 'whisper'

module ScholarspaceDerivativesServices
  module Concerns
    module VttGeneratable

      private

      def generate_vtt(file_path, output_dir:, title: File.basename(file_path, File.extname(file_path)))
        configure_whisper_cache_dir
        whisper = Whisper::Context.new('base')
        vtt = whisper.transcribe(file_path, Whisper::Params.new).to_webvtt

        vtt_path = "#{output_dir}/#{title}_VTT.vtt"
        File.open(vtt_path, 'w') { |file| file.write(vtt) }
        vtt_path
      end

      def configure_whisper_cache_dir
        cache_root = '/.cache/whispercpp'
        FileUtils.mkdir_p(cache_root)
        ENV['XDG_CACHE_HOME'] = cache_root
      end
    end
  end
end
