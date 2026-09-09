# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DerivativeJobs::FileSetLevel::PresentationVersion::FromPdfGenerateJob do
  describe '#perform' do
    it 'enqueues PDF presentation persist job when cache payload is generated' do
      work = instance_double('Work', id: 'work-pdf-1')
      service = instance_double(Derivatives::FileSetLevel::PresentationVersion::FromPdf)
      payload = {
        source_file_set_id: 'src-pdf-1',
        cache_file_identifier: 'cache-pdf-1',
        cache_filename: 'source_presentation_version.pdf'
      }

      allow(Hyrax.query_service).to receive(:find_by).with(id: 'work-pdf-1').and_return(work)
      allow(Derivatives::FileSetLevel::PresentationVersion::FromPdf).to receive(:new).with(work).and_return(service)
      allow(service).to receive(:generate_to_cache).with(source_file_set_id: 'src-pdf-1').and_return(payload)
      allow(DerivativeJobs::FileSetLevel::PresentationVersion::FromPdfPersistJob).to receive(:perform_later)

      described_class.new.perform(work_id: 'work-pdf-1', source_file_set_id: 'src-pdf-1')

      expect(DerivativeJobs::FileSetLevel::PresentationVersion::FromPdfPersistJob).to have_received(:perform_later).with(
        work_id: 'work-pdf-1',
        source_file_set_id: 'src-pdf-1',
        cache_file_identifier: 'cache-pdf-1',
        cache_filename: 'source_presentation_version.pdf'
      )
    end
  end
end
