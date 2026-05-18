# frozen_string_literal: true

class AudioTranscriptDerivativesJob < ApplicationJob
  queue_as :derivatives_audio_transcript

  def perform(work_id:)
    with_work(work_id: work_id) { |work| ScholarspaceDerivativesServices::AudioTranscriptDerivativesService.new(work).call }
  end
end
