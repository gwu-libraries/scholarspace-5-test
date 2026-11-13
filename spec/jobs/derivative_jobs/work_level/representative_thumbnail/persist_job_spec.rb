# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DerivativeJobs::WorkLevel::RepresentativeThumbnail::PersistJob do
  describe 'lock configuration' do
    it 'uses the long-running short-backoff lock profile' do
      expect(described_class::LOCK_TIMEOUT_SECONDS).to eq(LockRetryProfiles::LongRunningShortBackoff::LOCK_TIMEOUT_SECONDS)
      expect(described_class::LOCK_RETRY_ATTEMPTS).to eq(LockRetryProfiles::LongRunningShortBackoff::LOCK_RETRY_ATTEMPTS)
    end
  end

  describe '#perform' do
    it 'persists representative thumbnail via work-level service' do
      work = instance_double('Work', id: 'work-1')
      service = instance_double(Derivatives::WorkLevel::RepresentativeThumbnail::FromSourceFileSet)

      allow(Hyrax.query_service).to receive(:find_by).with(id: 'work-1').and_return(work)
      allow(Derivatives::WorkLevel::RepresentativeThumbnail::FromSourceFileSet).to receive(:new).with(work).and_return(service)
      allow(service).to receive(:persist_from_cache)

      described_class.new.perform(
        work_id: 'work-1',
        source_file_set_id: 'src-1',
        cache_file_identifier: 'cache-representative-thumbnail',
        cache_filename: 'REPRESENTATIVE_THUMBNAIL.jpg'
      )

      expect(service).to have_received(:persist_from_cache).with(
        source_file_set_id: 'src-1',
        cache_file_identifier: 'cache-representative-thumbnail',
        cache_filename: 'REPRESENTATIVE_THUMBNAIL.jpg'
      )
    end
  end

  describe '#lock_key_for' do
    it 'locks representative persist per work and source file set' do
      key = described_class.new.send(:lock_key_for, { work_id: 'work-1', source_file_set_id: 'src-1' })

      expect(key).to eq('derivatives:representative_thumbnail:work:work-1:source:src-1:persist')
    end
  end
end
