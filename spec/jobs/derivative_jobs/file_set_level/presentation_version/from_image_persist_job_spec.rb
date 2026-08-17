# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DerivativeJobs::FileSetLevel::PresentationVersion::FromImagePersistJob do
  subject(:job) { described_class.new }

  describe 'lock configuration' do
    it 'uses the long-running short-backoff lock profile' do
      expect(described_class::LOCK_TIMEOUT_SECONDS).to eq(LockRetryProfiles::LongRunningShortBackoff::LOCK_TIMEOUT_SECONDS)
      expect(described_class::LOCK_RETRY_ATTEMPTS).to eq(LockRetryProfiles::LongRunningShortBackoff::LOCK_RETRY_ATTEMPTS)
    end
  end

  describe '#perform' do
    it 'persists image presentation version from cache' do
      work = instance_double('Work', id: 'work-image-1')
      service = instance_double(Derivatives::FileSetLevel::PresentationVersion::FromImage)

      allow(Hyrax.query_service).to receive(:find_by).with(id: 'work-image-1').and_return(work)
      allow(Derivatives::FileSetLevel::PresentationVersion::FromImage).to receive(:new).with(work).and_return(service)
      allow(service).to receive(:persist_from_cache)

      job.perform(
        work_id: 'work-image-1',
        source_file_set_id: 'src-image-1',
        cache_file_identifier: 'cache-image-1',
        cache_filename: 'source_presentation_version.jpg'
      )

      expect(service).to have_received(:persist_from_cache).with(
        source_file_set_id: 'src-image-1',
        cache_file_identifier: 'cache-image-1',
        cache_filename: 'source_presentation_version.jpg'
      )
    end
  end

  describe '#lock_key_for' do
    it 'uses a per-work persist lock key for image presentation' do
      key = job.send(:lock_key_for, { work_id: 'work-1', source_file_set_id: 'image-99' })

      expect(key).to eq('derivatives:presentation_version:image:work:work-1:persist')
    end

    it 'serializes presentation image persists for different source files on the same work' do
      first_key = job.send(:lock_key_for, { work_id: 'work-1', source_file_set_id: 'image-1' })
      second_key = job.send(:lock_key_for, { work_id: 'work-1', source_file_set_id: 'image-2' })

      expect(first_key).to eq(second_key)
    end
  end
end
