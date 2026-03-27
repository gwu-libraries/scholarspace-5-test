# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ScholarspaceDerivativesServices::PdfToImagesDerivativesService do
  subject(:service) { described_class.new(work) }

  let(:work) { instance_double('Work', id: 'work-1') }
  let(:source_file_set) { instance_double('FileSet') }

  describe '#ensure_searchable_rendering_pdf' do
    let(:source_pdf_path) { '/tmp/source.pdf' }

    before do
      allow(service).to receive(:ocr_rendering_filename_for).with(source_file_set).and_return('source_OCR_RENDERING.pdf')
      allow(service).to receive(:file_set_attached_with_name?).with('source_OCR_RENDERING.pdf').and_return(false)
      service.instance_variable_set(:@working_dir, '/tmp/workdir')
    end

    it 'does not generate OCR derivative when source already has embedded text' do
      allow(service).to receive(:pdf_has_embedded_text?).with(source_pdf_path).and_return(true)
      allow(service).to receive(:generate_ocr_rendering_pdf)
      allow(service).to receive(:attach_files_to_work)

      service.ensure_searchable_rendering_pdf(source_pdf_path: source_pdf_path, source_file_set: source_file_set)

      expect(service).not_to have_received(:generate_ocr_rendering_pdf)
      expect(service).not_to have_received(:attach_files_to_work)
    end

    it 'generates and attaches OCR derivative when source does not have embedded text' do
      allow(service).to receive(:pdf_has_embedded_text?).with(source_pdf_path).and_return(false)
      allow(service).to receive(:generate_ocr_rendering_pdf).and_return(true)
      allow(service).to receive(:attach_files_to_work)

      service.ensure_searchable_rendering_pdf(source_pdf_path: source_pdf_path, source_file_set: source_file_set)

      expect(service).to have_received(:generate_ocr_rendering_pdf).with(
        source_pdf_path: source_pdf_path,
        ocr_output_path: '/tmp/workdir/pdfs/source_OCR_RENDERING.pdf'
      )
      expect(service).to have_received(:attach_files_to_work).with(
        ['/tmp/workdir/pdfs/source_OCR_RENDERING.pdf'],
        source_file_set: source_file_set
      )
    end
  end
end
