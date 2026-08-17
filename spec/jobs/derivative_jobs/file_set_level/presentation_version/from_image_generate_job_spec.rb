# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DerivativeJobs::FileSetLevel::PresentationVersion::FromImageGenerateJob do
  describe '#perform' do
    it 'enqueues image presentation persist job when cache payload is generated' do
      work = instance_double('Work', id: 'work-image-1')
      service = instance_double(Derivatives::FileSetLevel::PresentationVersion::FromImage)
      payload = {
        source_file_set_id: 'src-image-1',
        cache_file_identifier: 'cache-image-1',
        cache_filename: 'source_presentation_version.jpg'
      }

      allow(Hyrax.query_service).to receive(:find_by).with(id: 'work-image-1').and_return(work)
      allow(Derivatives::FileSetLevel::PresentationVersion::FromImage).to receive(:new).with(work).and_return(service)
      allow(service).to receive(:generate_to_cache).with(source_file_set_id: 'src-image-1').and_return(payload)
      allow(DerivativeJobs::FileSetLevel::PresentationVersion::FromImagePersistJob).to receive(:perform_later)

      described_class.new.perform(work_id: 'work-image-1', source_file_set_id: 'src-image-1')

      expect(DerivativeJobs::FileSetLevel::PresentationVersion::FromImagePersistJob).to have_received(:perform_later).with(
        work_id: 'work-image-1',
        source_file_set_id: 'src-image-1',
        cache_file_identifier: 'cache-image-1',
        cache_filename: 'source_presentation_version.jpg'
      )
    end
  end
end
