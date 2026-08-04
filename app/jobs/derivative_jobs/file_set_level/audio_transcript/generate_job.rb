# frozen_string_literal: true

class DerivativeJobs::FileSetLevel::AudioTranscript::GenerateJob < ApplicationJob
  queue_as :derivatives_audio_transcript_generate

  def perform(work_id:, source_file_set_id:)
    with_work(work_id: work_id) do |work|
      payload = Derivatives::FileSetLevel::TranscriptExtraction::FromAudioVideo
                .new(work)
                .generate_for_source_file_set_to_cache(source_file_set_id: source_file_set_id)

      next unless payload

      DerivativeJobs::FileSetLevel::AudioTranscript::PersistJob.perform_later(
        work_id: work.id.to_s,
        source_file_set_id: payload.fetch(:source_file_set_id),
        cache_file_identifier: payload.fetch(:cache_file_identifier),
        cache_filename: payload.fetch(:cache_filename)
      )
    end
  end
end
