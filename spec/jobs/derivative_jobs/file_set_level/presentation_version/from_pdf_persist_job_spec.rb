# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DerivativeJobs::FileSetLevel::PresentationVersion::FromPdfPersistJob do
  subject(:job) { described_class.new }

  describe '#perform' do
    it 'persists PDF presentation version from cache' do
      work = instance_double('Work', id: 'work-pdf-1')
      service = instance_double(Derivatives::FileSetLevel::PresentationVersion::FromPdf)

      allow(Hyrax.query_service).to receive(:find_by).with(id: 'work-pdf-1').and_return(work)
      allow(Derivatives::FileSetLevel::PresentationVersion::FromPdf).to receive(:new).with(work).and_return(service)
      allow(service).to receive(:persist_from_cache)

      job.perform(
        work_id: 'work-pdf-1',
        source_file_set_id: 'src-pdf-1',
        cache_file_identifier: 'cache-pdf-1',
        cache_filename: 'source_presentation_version.pdf'
      )

      expect(service).to have_received(:persist_from_cache).with(
        source_file_set_id: 'src-pdf-1',
        cache_file_identifier: 'cache-pdf-1',
        cache_filename: 'source_presentation_version.pdf'
      )
    end
  end

  describe '#lock_key_for' do
    it 'uses per-source persist lock key for PDF presentation' do
      key = job.send(:lock_key_for, { work_id: 'work-1', source_file_set_id: 'pdf-99' })

      expect(key).to eq('derivatives:presentation_version:pdf:work:work-1:source:pdf-99:persist')
    end
  end
end
