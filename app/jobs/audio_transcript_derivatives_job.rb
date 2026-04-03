# frozen_string_literal: true

class AudioTranscriptDerivativesJob < ApplicationJob
  queue_as :derivatives_audio_transcript

  def perform(work_id:)
    work = Hyrax.query_service.find_by(id: work_id)
    return unless work

    ScholarspaceDerivativesServices::AudioTranscriptDerivativesService.new(work).call
  end
end
