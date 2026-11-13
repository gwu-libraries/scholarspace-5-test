# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DerivativeJobs::FileSetLevel::TextExtraction::FromPdfGenerateJob do
  subject(:job) { described_class.new }

  describe 'queue configuration' do
    it 'uses the PDF text generate queue' do
      expect(described_class.queue_name).to eq('derivatives_text_extraction_from_pdf_generate')
    end
  end

  describe '#lock_key_for' do
    it 'uses per-pdf lock when pdf_file_set_id is provided' do
      key = job.send(:lock_key_for, { work_id: 'work-1', pdf_file_set_id: 'pdf-99' })

      expect(key).to eq('derivatives:text_extraction_from_pdf:work:work-1:pdf:pdf-99')
    end
  end

  describe '#perform' do
    it 'enqueues persist job when cache payload is generated' do
      work = instance_double('Work', id: 'work-1')
      service = instance_double(Derivatives::FileSetLevel::TextExtraction::FromPdf)
      payload = {
        source_file_set_id: 'pdf-99',
        cache_file_identifier_hocr: 'cache-hocr-1',
        cache_filename_hocr: 'Sample_HOCR.hocr',
        cache_file_identifier_pdf: 'cache-pdf-1',
        cache_filename_pdf: 'Sample_presentation_version.pdf'
      }

      allow(Hyrax.query_service).to receive(:find_by).with(id: 'work-1').and_return(work)
  allow(Derivatives::FileSetLevel::TextExtraction::FromPdf).to receive(:new).with(work).and_return(service)
      allow(service).to receive(:generate_to_cache).with(pdf_file_set_id: 'pdf-99').and_return(payload)
      allow(DerivativeJobs::FileSetLevel::TextExtraction::FromPdfPersistJob).to receive(:perform_later)

      job.perform(work_id: 'work-1', pdf_file_set_id: 'pdf-99')

      expect(DerivativeJobs::FileSetLevel::TextExtraction::FromPdfPersistJob).to have_received(:perform_later).with(
        work_id: 'work-1',
        source_file_set_id: 'pdf-99',
        cache_file_identifier_hocr: 'cache-hocr-1',
        cache_filename_hocr: 'Sample_HOCR.hocr',
        cache_file_identifier_pdf: 'cache-pdf-1',
        cache_filename_pdf: 'Sample_presentation_version.pdf'
      )
    end

    it 'enqueues persist job when cache payload only includes a presentation PDF' do
      work = instance_double('Work', id: 'work-1')
      service = instance_double(Derivatives::FileSetLevel::TextExtraction::FromPdf)
      payload = {
        source_file_set_id: 'pdf-99',
        cache_file_identifier_hocr: nil,
        cache_filename_hocr: nil,
        cache_file_identifier_pdf: 'cache-pdf-1',
        cache_filename_pdf: 'Sample_presentation_version.pdf'
      }

      allow(Hyrax.query_service).to receive(:find_by).with(id: 'work-1').and_return(work)
      allow(Derivatives::FileSetLevel::TextExtraction::FromPdf).to receive(:new).with(work).and_return(service)
      allow(service).to receive(:generate_to_cache).with(pdf_file_set_id: 'pdf-99').and_return(payload)
      allow(DerivativeJobs::FileSetLevel::TextExtraction::FromPdfPersistJob).to receive(:perform_later)

      job.perform(work_id: 'work-1', pdf_file_set_id: 'pdf-99')

      expect(DerivativeJobs::FileSetLevel::TextExtraction::FromPdfPersistJob).to have_received(:perform_later).with(
        work_id: 'work-1',
        source_file_set_id: 'pdf-99',
        cache_file_identifier_hocr: nil,
        cache_filename_hocr: nil,
        cache_file_identifier_pdf: 'cache-pdf-1',
        cache_filename_pdf: 'Sample_presentation_version.pdf'
      )
    end
  end
end
