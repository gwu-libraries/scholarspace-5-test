# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DerivativeJobs::FileSetLevel::PresentationVersion::FromAudioVisualPersistJob do
  subject(:job) { described_class.new }

  describe '#perform' do
    it 'persists audio visual presentation version from cache' do
      work = instance_double('Work', id: 'work-audio_visual-1')
      service = instance_double(Derivatives::FileSetLevel::PresentationVersion::FromAudioVisual)

      allow(Hyrax.query_service).to receive(:find_by).with(id: 'work-audio_visual-1').and_return(work)
      allow(Derivatives::FileSetLevel::PresentationVersion::FromAudioVisual).to receive(:new).with(work).and_return(service)
      allow(service).to receive(:persist_from_cache)

      job.perform(
        work_id: 'work-audio_visual-1',
        source_file_set_id: 'src-audio_visual-1',
        cache_file_identifier: 'cache-audio_visual-1',
        cache_filename: 'source_presentation_version.mp4'
      )

      expect(service).to have_received(:persist_from_cache).with(
        source_file_set_id: 'src-audio_visual-1',
        cache_file_identifier: 'cache-audio_visual-1',
        cache_filename: 'source_presentation_version.mp4'
      )
    end
  end

  describe '#lock_key_for' do
    it 'uses per-source persist lock key for audio visual presentation' do
      key = job.send(:lock_key_for, { work_id: 'work-1', source_file_set_id: 'audio_visual-99' })

      expect(key).to eq('derivatives:presentation_version:audio_visual:work:work-1:source:audio_visual-99:persist')
    end
  end
end
