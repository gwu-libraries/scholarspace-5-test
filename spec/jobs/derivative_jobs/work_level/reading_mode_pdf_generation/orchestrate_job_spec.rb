# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DerivativeJobs::WorkLevel::ReadingModePdfGeneration::OrchestrateJob do
  describe '#perform' do
    it 'fans out per-image jobs and enqueues separate PDF/hOCR assembly jobs' do
      work = instance_double('Work', id: 'work-joined-1')

      allow(Hyrax.query_service).to receive(:find_by).with(id: 'work-joined-1').and_return(work)
      allow(Derivatives::FileSetLevel::TextExtraction::FromImages).to receive(:source_image_file_set_ids).with(work).and_return(%w[fs-1 fs-2])
      allow(DerivativeJobs::FileSetLevel::TextExtraction::FromImagesGenerateJob).to receive(:perform_later)

      from_images_generate_setter = instance_double('ActiveJob::ConfiguredJob')
      allow(DerivativeJobs::WorkLevel::ReadingModePdfGeneration::FromImagesGenerateJob).to receive(:set).with(wait: described_class::FROM_IMAGES_GENERATE_WAIT).and_return(from_images_generate_setter)
      allow(from_images_generate_setter).to receive(:perform_later)

      assemble_hocr_setter = instance_double('ActiveJob::ConfiguredJob')
      allow(DerivativeJobs::WorkLevel::ReadingModePdfGeneration::AssembleHocrJob).to receive(:set).with(wait: described_class::ASSEMBLE_HOCR_WAIT).and_return(assemble_hocr_setter)
      allow(assemble_hocr_setter).to receive(:perform_later)

      described_class.new.perform(work_id: 'work-joined-1')

      expect(DerivativeJobs::FileSetLevel::TextExtraction::FromImagesGenerateJob).to have_received(:perform_later).with(
        work_id: 'work-joined-1',
        source_file_set_id: 'fs-1'
      )
      expect(DerivativeJobs::FileSetLevel::TextExtraction::FromImagesGenerateJob).to have_received(:perform_later).with(
        work_id: 'work-joined-1',
        source_file_set_id: 'fs-2'
      )
      expect(from_images_generate_setter).to have_received(:perform_later).with(work_id: 'work-joined-1')
      expect(assemble_hocr_setter).to have_received(:perform_later).with(work_id: 'work-joined-1')
    end

    it 'does nothing when work is not found' do
      allow(Hyrax.query_service).to receive(:find_by).with(id: 'missing-work').and_return(nil)
      allow(DerivativeJobs::FileSetLevel::TextExtraction::FromImagesGenerateJob).to receive(:perform_later)

      described_class.new.perform(work_id: 'missing-work')

      expect(DerivativeJobs::FileSetLevel::TextExtraction::FromImagesGenerateJob).not_to have_received(:perform_later)
    end
  end
end
