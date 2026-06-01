# frozen_string_literal: true

class AudioTranscriptDerivativesJob < ApplicationJob
  queue_as :audio_transcript

  def perform(work_id:)
    with_work(work_id: work_id) { |work| Derivatives::AudioTranscript.new(work).call }
  end
end
