# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DerivativeJobs::FileSetLevel::TextExtraction::FromPdfPersistJob do
  subject(:job) { described_class.new }

  describe 'queue configuration' do
    it 'uses the PDF text persist queue' do
      expect(described_class.queue_name).to eq('derivatives_text_extraction_from_pdf_persist')
    end
  end

  describe '#perform' do
    it 'persists PDF hOCR and presentation version from cache via service' do
      work = instance_double('Work', id: 'work-1')
      service = instance_double(Derivatives::FileSetLevel::TextExtraction::FromPdf)

      allow(Hyrax.query_service).to receive(:find_by).with(id: 'work-1').and_return(work)
  allow(Derivatives::FileSetLevel::TextExtraction::FromPdf).to receive(:new).with(work).and_return(service)
      allow(service).to receive(:persist_from_cache)

      job.perform(
        work_id: 'work-1',
        source_file_set_id: 'pdf-99',
        cache_file_identifier_hocr: 'cache-hocr-1',
        cache_filename_hocr: 'Sample_HOCR.hocr',
        cache_file_identifier_pdf: 'cache-pdf-1',
        cache_filename_pdf: 'Sample_presentation_version.pdf'
      )

      expect(service).to have_received(:persist_from_cache).with(
        source_file_set_id: 'pdf-99',
        cache_file_identifier_hocr: 'cache-hocr-1',
        cache_filename_hocr: 'Sample_HOCR.hocr',
        cache_file_identifier_pdf: 'cache-pdf-1',
        cache_filename_pdf: 'Sample_presentation_version.pdf'
      )
    end

    it 'persists presentation version from cache when hOCR cache fields are nil' do
      work = instance_double('Work', id: 'work-1')
      service = instance_double(Derivatives::FileSetLevel::TextExtraction::FromPdf)

      allow(Hyrax.query_service).to receive(:find_by).with(id: 'work-1').and_return(work)
      allow(Derivatives::FileSetLevel::TextExtraction::FromPdf).to receive(:new).with(work).and_return(service)
      allow(service).to receive(:persist_from_cache)

      job.perform(
        work_id: 'work-1',
        source_file_set_id: 'pdf-99',
        cache_file_identifier_hocr: nil,
        cache_filename_hocr: nil,
        cache_file_identifier_pdf: 'cache-pdf-1',
        cache_filename_pdf: 'Sample_presentation_version.pdf'
      )

      expect(service).to have_received(:persist_from_cache).with(
        source_file_set_id: 'pdf-99',
        cache_file_identifier_hocr: nil,
        cache_filename_hocr: nil,
        cache_file_identifier_pdf: 'cache-pdf-1',
        cache_filename_pdf: 'Sample_presentation_version.pdf'
      )
    end
  end

  describe '#lock_key_for' do
    it 'uses per-source persist lock key for PDF text extraction' do
      key = job.send(:lock_key_for, { work_id: 'work-1', source_file_set_id: 'pdf-99' })

      expect(key).to eq('derivatives:text_extraction_from_pdf:work:work-1:source:pdf-99:persist')
    end
  end
end
