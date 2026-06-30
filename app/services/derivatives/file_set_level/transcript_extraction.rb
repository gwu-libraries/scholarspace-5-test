# frozen_string_literal: true

module Derivatives
  module FileSetLevel
    module TranscriptExtraction
      def self.from_audio_video(work)
        FromAudioVideo.new(work)
      end
    end
  end
end
