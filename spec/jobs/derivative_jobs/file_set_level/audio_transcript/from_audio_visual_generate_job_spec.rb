# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DerivativeJobs::FileSetLevel::AudioTranscript::FromAudioVisualGenerateJob do
  describe '#perform' do
    it 'enqueues transcript persist job when cache payload is generated' do
      work = instance_double('Work', id: 'work-audio-1')
      service = instance_double(Derivatives::FileSetLevel::TranscriptExtraction::FromAudioVisual)
      payload = {
        source_file_set_id: 'src-1',
        cache_file_identifier: 'cache-audio-1',
        cache_filename: 'source_VTT.vtt'
      }

      allow(Hyrax.query_service).to receive(:find_by).with(id: 'work-audio-1').and_return(work)
  allow(Derivatives::FileSetLevel::TranscriptExtraction::FromAudioVisual).to receive(:new).with(work).and_return(service)
      allow(service).to receive(:generate_to_cache).with(source_file_set_id: 'src-1').and_return(payload)
      allow(DerivativeJobs::FileSetLevel::AudioTranscript::FromAudioVisualPersistJob).to receive(:perform_later)

      described_class.new.perform(work_id: 'work-audio-1', source_file_set_id: 'src-1')

      expect(DerivativeJobs::FileSetLevel::AudioTranscript::FromAudioVisualPersistJob).to have_received(:perform_later).with(
        work_id: 'work-audio-1',
        source_file_set_id: 'src-1',
        cache_file_identifier: 'cache-audio-1',
        cache_filename: 'source_VTT.vtt'
      )
    end
  end
end
