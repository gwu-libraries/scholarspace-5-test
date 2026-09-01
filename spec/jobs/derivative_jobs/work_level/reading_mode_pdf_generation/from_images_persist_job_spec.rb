# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DerivativeJobs::WorkLevel::ReadingModePdfGeneration::FromImagesPersistJob do
  describe 'lock configuration' do
    it 'uses the long-running short-backoff lock profile' do
      expect(described_class::LOCK_TIMEOUT_SECONDS).to eq(LockRetryProfiles::LongRunningShortBackoff::LOCK_TIMEOUT_SECONDS)
      expect(described_class::LOCK_RETRY_ATTEMPTS).to eq(LockRetryProfiles::LongRunningShortBackoff::LOCK_RETRY_ATTEMPTS)
    end
  end

  describe 'queue configuration' do
    it 'uses the image PDF persist queue' do
      expect(described_class.queue_name).to eq('derivatives_reading_mode_pdf_generation_from_images_persist')
    end
  end

  describe '#perform' do
    it 'persists reading mode PDF from cache' do
      work = instance_double('Work', id: 'work-1')
      service = instance_double(Derivatives::WorkLevel::ReadingModePdfGeneration::FromImages)

      allow(Hyrax.query_service).to receive(:find_by).with(id: 'work-1').and_return(work)
      allow(Derivatives::WorkLevel::ReadingModePdfGeneration::FromImages).to receive(:new).with(work).and_return(service)
      allow(service).to receive(:persist_from_cache)

      described_class.new.perform(
        work_id: 'work-1',
        source_file_set_id: 'image-1',
        cache_file_identifier: 'cache-reading-mode-pdf',
        cache_filename: 'reading_mode_pdf.pdf'
      )

      expect(service).to have_received(:persist_from_cache).with(
        source_file_set_id: 'image-1',
        cache_file_identifier: 'cache-reading-mode-pdf',
        cache_filename: 'reading_mode_pdf.pdf'
      )
    end
  end

  describe '#lock_key_for' do
    it 'locks reading mode PDF persistence per work and source file set' do
      key = described_class.new.send(:lock_key_for, { work_id: 'work-1', source_file_set_id: 'image-1' })

      expect(key).to eq('derivatives:reading_mode_pdf_generation:work:work-1:source:image-1:from_images_persist')
    end
  end
end