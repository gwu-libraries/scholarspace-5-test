# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DerivativeJobs::WorkLevel::ReadingModePdfGeneration::FromImagesGenerateJob do
  describe '#perform' do
    it 'generates reading mode PDF to cache and enqueues persist job' do
      work = instance_double('Work', id: 'work-1')
      source_image_file_sets = [instance_double('FileSet', id: 'image-1')]
      text_service = instance_double(Derivatives::FileSetLevel::TextExtraction::FromImages, source_image_file_sets: source_image_file_sets)
      pdf_service = instance_double(Derivatives::WorkLevel::ReadingModePdfGeneration::FromImages)
      payload = {
        source_file_set_id: 'image-1',
        cache_file_identifier: 'cache-reading-mode-pdf',
        cache_filename: 'reading_mode_pdf.pdf'
      }

      allow(Hyrax.query_service).to receive(:find_by).with(id: 'work-1').and_return(work)
      allow(Derivatives::FileSetLevel::TextExtraction::FromImages).to receive(:new).with(work).and_return(text_service)
      allow(Derivatives::WorkLevel::ReadingModePdfGeneration::FromImages).to receive(:new).with(work).and_return(pdf_service)
      allow(pdf_service).to receive(:generate_to_cache).with(source_image_file_sets: source_image_file_sets).and_return(payload)
      allow(DerivativeJobs::WorkLevel::ReadingModePdfGeneration::FromImagesPersistJob).to receive(:perform_later)

      described_class.new.perform(work_id: 'work-1')

      expect(DerivativeJobs::WorkLevel::ReadingModePdfGeneration::FromImagesPersistJob).to have_received(:perform_later).with(
        work_id: 'work-1',
        source_file_set_id: 'image-1',
        cache_file_identifier: 'cache-reading-mode-pdf',
        cache_filename: 'reading_mode_pdf.pdf'
      )
    end
  end

  describe 'lock configuration' do
    it 'uses the long-running short-backoff lock profile' do
      expect(described_class::LOCK_TIMEOUT_SECONDS).to eq(LockRetryProfiles::LongRunningShortBackoff::LOCK_TIMEOUT_SECONDS)
      expect(described_class::LOCK_RETRY_ATTEMPTS).to eq(LockRetryProfiles::LongRunningShortBackoff::LOCK_RETRY_ATTEMPTS)
    end
  end

  describe 'queue configuration' do
    it 'uses the image PDF assembly queue' do
      expect(described_class.queue_name).to eq('derivatives_reading_mode_pdf_generation_from_images_generate')
    end
  end

  describe '#lock_key_for' do
    it 'locks only image PDF assembly per work' do
      key = described_class.new.send(:lock_key_for, { work_id: 'work-1' })

      expect(key).to eq('derivatives:reading_mode_pdf_generation:work:work-1:from_images_generate')
    end
  end
end