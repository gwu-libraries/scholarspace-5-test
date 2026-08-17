# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DerivativeJobs::FileSetLevel::PresentationVersion::FromAudioVisualGenerateJob do
  describe '#perform' do
    it 'enqueues audio visual presentation persist job when cache payload is generated' do
      work = instance_double('Work', id: 'work-audio_visual-1')
      service = instance_double(Derivatives::FileSetLevel::PresentationVersion::FromAudioVisual)
      payload = {
        source_file_set_id: 'src-audio_visual-1',
        cache_file_identifier: 'cache-audio_visual-1',
        cache_filename: 'source_presentation_version.mp4'
      }

      allow(Hyrax.query_service).to receive(:find_by).with(id: 'work-audio_visual-1').and_return(work)
      allow(Derivatives::FileSetLevel::PresentationVersion::FromAudioVisual).to receive(:new).with(work).and_return(service)
      allow(service).to receive(:generate_to_cache).with(source_file_set_id: 'src-audio_visual-1').and_return(payload)
      allow(DerivativeJobs::FileSetLevel::PresentationVersion::FromAudioVisualPersistJob).to receive(:perform_later)

      described_class.new.perform(work_id: 'work-audio_visual-1', source_file_set_id: 'src-audio_visual-1')

      expect(DerivativeJobs::FileSetLevel::PresentationVersion::FromAudioVisualPersistJob).to have_received(:perform_later).with(
        work_id: 'work-audio_visual-1',
        source_file_set_id: 'src-audio_visual-1',
        cache_file_identifier: 'cache-audio_visual-1',
        cache_filename: 'source_presentation_version.mp4'
      )
    end
  end
end
