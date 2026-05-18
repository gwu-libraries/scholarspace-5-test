# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ImagesToPdfDerivativesJob do
  describe '#perform' do
    it 'runs image-to-pdf generation and then enqueues PDF text extraction' do
      work = instance_double('Work', id: 'work-joined-1')
      service = instance_double(ScholarspaceDerivativesServices::ImagesToPdfDerivativesService, call: true)

      allow(Hyrax.query_service).to receive(:find_by).with(id: 'work-joined-1').and_return(work)
      allow(ScholarspaceDerivativesServices::ImagesToPdfDerivativesService).to receive(:new).with(work).and_return(service)
      allow(PdfTextExtractionJob).to receive(:perform_later)

      described_class.new.perform(work_id: 'work-joined-1')

      expect(service).to have_received(:call)
      expect(PdfTextExtractionJob).to have_received(:perform_later).with(work_id: 'work-joined-1')
    end

    it 'does nothing when work is not found' do
      allow(Hyrax.query_service).to receive(:find_by).with(id: 'missing-work').and_return(nil)
      allow(PdfTextExtractionJob).to receive(:perform_later)

      described_class.new.perform(work_id: 'missing-work')

      expect(PdfTextExtractionJob).not_to have_received(:perform_later)
    end
  end
end
