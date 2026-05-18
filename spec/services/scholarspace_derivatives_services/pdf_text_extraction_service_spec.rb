# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ScholarspaceDerivativesServices::PdfTextExtractionService do
  subject(:service) { described_class.new(work) }

  let(:work) do
    instance_double('Work', id: 'work-pdf-1', depositor: 'depositor@example.edu', member_ids: ['pdf-fs-1'])
  end

  let(:pdf_original_file) do
    instance_double(
      'OriginalFile',
      mime_type: 'application/pdf',
      original_filename: 'Sample Document.pdf',
      file_identifier: 'fid-123'
    )
  end

  let(:pdf_file_set) do
    instance_double('FileSet', id: 'pdf-fs-1', original_file: pdf_original_file, service_file: false, related_url: [])
  end

  let(:pdf_file_set_with_variant_mime) do
    original_file = instance_double(
      'OriginalFile',
      mime_type: 'application/pdf; charset=binary',
      original_filename: 'Variant MIME.pdf',
      file_identifier: 'fid-variant'
    )
    instance_double('FileSet', id: 'pdf-fs-variant', original_file: original_file, service_file: false, related_url: [])
  end

  let(:pdf_file_set_with_blank_mime) do
    original_file = instance_double(
      'OriginalFile',
      mime_type: nil,
      original_filename: 'Fallback By Name.pdf',
      file_identifier: 'fid-fallback'
    )
    instance_double('FileSet', id: 'pdf-fs-blank', original_file: original_file, service_file: false, related_url: [])
  end

  let(:joined_pdf_service_file_set) do
    original_file = instance_double(
      'OriginalFile',
      mime_type: 'application/pdf',
      original_filename: 'joined_images_pdf.pdf',
      file_identifier: 'fid-joined'
    )
    instance_double('FileSet', id: 'pdf-fs-joined', original_file: original_file, service_file: true, related_url: [])
  end

  let(:non_joined_service_pdf_file_set) do
    original_file = instance_double(
      'OriginalFile',
      mime_type: 'application/pdf',
      original_filename: 'other_service.pdf',
      file_identifier: 'fid-other'
    )
    instance_double('FileSet', id: 'pdf-fs-other', original_file: original_file, service_file: true, related_url: [])
  end

  describe '#expected_hocr_filename_for' do
    it 'uses _HOCR suffix for extracted sidecar names' do
      expect(service.send(:expected_hocr_filename_for, pdf_file_set)).to eq('Sample Document_HOCR.hocr')
    end
  end

  describe '#find_pdf_file_sets_needing_extraction' do
    it 'includes source pdf when no matching _HOCR sidecar exists' do
      allow(service).to receive(:member_file_sets).and_return([pdf_file_set])

      result = service.send(:find_pdf_file_sets_needing_extraction)
      expect(result).to eq([pdf_file_set])
    end

    it 'does not skip source pdf when only filename-based _HOCR sidecar exists' do
      hocr_original_file = instance_double(
        'OriginalFile',
        original_filename: 'Sample Document_HOCR.hocr',
        mime_type: 'text/vnd.hocr+html'
      )
      hocr_file_set = instance_double('FileSet', original_file: hocr_original_file, service_file: true, related_url: [])
      allow(service).to receive(:member_file_sets).and_return([pdf_file_set, hocr_file_set])

      result = service.send(:find_pdf_file_sets_needing_extraction)
      expect(result).to eq([pdf_file_set])
    end

    it 'skips source pdf when metadata-linked HOCR sidecar already exists with non-standard filename' do
      hocr_original_file = instance_double(
        'OriginalFile',
        original_filename: 'manual-ocr-name.hocr',
        mime_type: 'text/vnd.hocr+html'
      )
      hocr_file_set = instance_double(
        'FileSet',
        original_file: hocr_original_file,
        service_file: true,
        related_url: ['source_file_set_id:pdf-fs-1']
      )
      allow(service).to receive(:member_file_sets).and_return([pdf_file_set, hocr_file_set])

      result = service.send(:find_pdf_file_sets_needing_extraction)
      expect(result).to eq([])
    end

    it 'does not skip source pdf when only metadata-linked thumbnail exists' do
      thumbnail_original_file = instance_double(
        'OriginalFile',
        original_filename: 'Sample Document_THUMBNAIL.jpg',
        mime_type: 'application/octet-stream'
      )
      thumbnail_file_set = instance_double(
        'FileSet',
        original_file: thumbnail_original_file,
        service_file: true,
        related_url: ['source_file_set_id:pdf-fs-1']
      )
      allow(service).to receive(:member_file_sets).and_return([pdf_file_set, thumbnail_file_set])

      result = service.send(:find_pdf_file_sets_needing_extraction)
      expect(result).to eq([pdf_file_set])
    end

    it 'includes PDF when MIME type has parameters' do
      allow(service).to receive(:member_file_sets).and_return([pdf_file_set_with_variant_mime])

      result = service.send(:find_pdf_file_sets_needing_extraction)
      expect(result).to eq([pdf_file_set_with_variant_mime])
    end

    it 'includes PDF when MIME type is blank but filename ends with .pdf' do
      allow(service).to receive(:member_file_sets).and_return([pdf_file_set_with_blank_mime])

      result = service.send(:find_pdf_file_sets_needing_extraction)
      expect(result).to eq([pdf_file_set_with_blank_mime])
    end

    it 'includes joined image-derived service PDF when no matching _HOCR sidecar exists' do
      allow(service).to receive(:member_file_sets).and_return([joined_pdf_service_file_set])

      result = service.send(:find_pdf_file_sets_needing_extraction)
      expect(result).to eq([joined_pdf_service_file_set])
    end

    it 'skips non-joined service PDFs' do
      allow(service).to receive(:member_file_sets).and_return([non_joined_service_pdf_file_set])

      result = service.send(:find_pdf_file_sets_needing_extraction)
      expect(result).to eq([])
    end
  end

  describe '#process_pdf' do
    it 'extracts and attaches HOCR for PDFs' do
      allow(Dir).to receive(:mktmpdir).and_return('/tmp/pdf_extraction_test')
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with('/tmp/pdf_extraction_test').and_return(true)
      allow(File).to receive(:exist?).with('/tmp/pdf_extraction_test/Sample Document_HOCR.hocr').and_return(true)
      allow(FileUtils).to receive(:rm_rf)
      allow(service).to receive(:fetch_pdf_file).and_return('/tmp/pdf_extraction_test/document.pdf')
      allow(service).to receive(:extract_hocr_for_pdf).and_return('/tmp/pdf_extraction_test/Sample Document_HOCR.hocr')
      allow(service).to receive(:attach_hocr_to_work)

      service.send(:process_pdf, pdf_file_set)

      expect(service).to have_received(:extract_hocr_for_pdf).with(
        '/tmp/pdf_extraction_test/document.pdf',
        '/tmp/pdf_extraction_test',
        'Sample Document_HOCR.hocr'
      )
      expect(service).to have_received(:attach_hocr_to_work).with('/tmp/pdf_extraction_test/Sample Document_HOCR.hocr', pdf_file_set)
    end

    it 'extracts and attaches HOCR when PDF has embedded text' do
      allow(Dir).to receive(:mktmpdir).and_return('/tmp/pdf_extraction_test')
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with('/tmp/pdf_extraction_test').and_return(true)
      allow(File).to receive(:exist?).with('/tmp/pdf_extraction_test/Sample Document_HOCR.hocr').and_return(true)
      allow(FileUtils).to receive(:rm_rf)
      allow(service).to receive(:fetch_pdf_file).and_return('/tmp/pdf_extraction_test/document.pdf')
      allow(service).to receive(:extract_hocr_for_pdf).and_return('/tmp/pdf_extraction_test/Sample Document_HOCR.hocr')
      allow(service).to receive(:attach_hocr_to_work)

      service.send(:process_pdf, pdf_file_set)

      expect(service).to have_received(:extract_hocr_for_pdf).with(
        '/tmp/pdf_extraction_test/document.pdf',
        '/tmp/pdf_extraction_test',
        'Sample Document_HOCR.hocr'
      )
      expect(service).to have_received(:attach_hocr_to_work).with('/tmp/pdf_extraction_test/Sample Document_HOCR.hocr', pdf_file_set)
    end
  end

  describe '#convert_pdf_to_images' do
    it 'uses a page output prefix and returns generated page png paths' do
      success_status = instance_double(Process::Status, success?: true)
      allow(Open3).to receive(:capture3).and_return(['', '', success_status])
      allow(Dir).to receive(:glob).and_call_original
      allow(Dir).to receive(:glob).with('/tmp/pdf/page-*.png').and_return(['/tmp/pdf/page-01.png', '/tmp/pdf/page-02.png'])

      result = service.send(:convert_pdf_to_images, '/tmp/pdf/document.pdf', '/tmp/pdf')

      expect(Open3).to have_received(:capture3).with(
        'pdftoppm', '-r', '150', '-png', '/tmp/pdf/document.pdf', '/tmp/pdf/page'
      )
      expect(result).to eq(['/tmp/pdf/page-01.png', '/tmp/pdf/page-02.png'])
    end
  end

end
