# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DerivativeJobs::FileSetLevel::AudioTranscript::FromAudioVisualPersistJob do
  describe '#perform' do
    it 'persists transcript from cache via service' do
      work = instance_double('Work', id: 'work-audio-1')
      service = instance_double(Derivatives::FileSetLevel::TranscriptExtraction::FromAudioVisual)

      allow(Hyrax.query_service).to receive(:find_by).with(id: 'work-audio-1').and_return(work)
  allow(Derivatives::FileSetLevel::TranscriptExtraction::FromAudioVisual).to receive(:new).with(work).and_return(service)
      allow(service).to receive(:persist_from_cache)

      described_class.new.perform(
        work_id: 'work-audio-1',
        source_file_set_id: 'src-1',
        cache_file_identifier: 'cache-audio-1',
        cache_filename: 'source_VTT.vtt'
      )

      expect(service).to have_received(:persist_from_cache).with(
        source_file_set_id: 'src-1',
        cache_file_identifier: 'cache-audio-1',
        cache_filename: 'source_VTT.vtt'
      )
    end
  end

  describe '#lock_key_for' do
    it 'locks per work and source file set for persist' do
      key = described_class.new.send(
        :lock_key_for,
        { work_id: 'work-audio-1', source_file_set_id: 'src-1' }
      )

      expect(key).to eq('derivatives:audio_transcript:work:work-audio-1:source:src-1:persist')
    end
  end
end
