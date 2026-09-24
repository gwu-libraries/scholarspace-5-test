# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Derivatives::FileSetLevel::TextExtraction::FromPdf do
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

  let(:reading_mode_pdf_service_file_set) do
    original_file = instance_double(
      'OriginalFile',
      mime_type: 'application/pdf',
      original_filename: 'reading_mode_pdf.pdf',
      file_identifier: 'fid-reading-mode'
    )
    instance_double('FileSet', id: 'pdf-fs-reading-mode', original_file: original_file, service_file: true, related_url: [])
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

    it 'skips source pdf when HOCR sidecar is tagged by derivative_type despite octet-stream mime' do
      hocr_original_file = instance_double(
        'OriginalFile',
        original_filename: 'Sample Document_HOCR.hocr',
        mime_type: 'application/octet-stream'
      )
      presentation_file_set = instance_double('FileSet')
      hocr_file_set = instance_double(
        'FileSet',
        original_file: hocr_original_file,
        service_file: true,
        related_url: ['source_file_set_id:pdf-fs-1', 'derivative_type:hocr']
      )
      allow(service).to receive(:member_file_sets).and_return([pdf_file_set, hocr_file_set])
      allow(service).to receive(:find_presentation_pdf_for).with(pdf_file_set).and_return(presentation_file_set)
      allow(service).to receive(:presentation_pdf_contains_embedded_text?).with(presentation_file_set).and_return(true)

      result = service.send(:find_pdf_file_sets_needing_extraction)
      expect(result).to eq([])
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

    it 'does not skip source pdf when metadata-linked HOCR sidecar exists but presentation is missing/searchless' do
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
      expect(result).to eq([pdf_file_set])
    end

    it 'skips source pdf when extraction artifacts are complete' do
      allow(service).to receive(:member_file_sets).and_return([pdf_file_set])
      allow(service).to receive(:extraction_artifacts_complete_for?).with(pdf_file_set).and_return(true)

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

    it 'includes reading mode image-derived service PDF when no matching _HOCR sidecar exists' do
      allow(service).to receive(:member_file_sets).and_return([reading_mode_pdf_service_file_set])

      result = service.send(:find_pdf_file_sets_needing_extraction)
      expect(result).to eq([reading_mode_pdf_service_file_set])
    end

    it 'skips non-joined service PDFs' do
      allow(service).to receive(:member_file_sets).and_return([non_joined_service_pdf_file_set])

      result = service.send(:find_pdf_file_sets_needing_extraction)
      expect(result).to eq([])
    end
  end

  describe '#generate_to_cache' do
    it 'extracts and caches both HOCR and presentation PDF payload' do
      allow(service).to receive(:member_file_sets).and_return([pdf_file_set])
      allow(Dir).to receive(:mktmpdir).and_return('/tmp/pdf_extraction_test')
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with('/tmp/pdf_extraction_test').and_return(true)
      allow(File).to receive(:exist?).with('/tmp/pdf_extraction_test/Sample Document_HOCR.hocr').and_return(true)
      allow(File).to receive(:exist?).with('/tmp/pdf_extraction_test/Sample Document_presentation_version.pdf').and_return(true)
      allow(FileUtils).to receive(:rm_rf)
      allow(service).to receive(:fetch_pdf_file).and_return('/tmp/pdf_extraction_test/document.pdf')
      allow(service).to receive(:pdf_contains_embedded_text?).and_return(false)
      allow(service).to receive(:extract_hocr_for_pdf).and_return('/tmp/pdf_extraction_test/Sample Document_HOCR.hocr')
      allow(service).to receive(:generate_embedded_text_pdf).and_return('/tmp/pdf_extraction_test/Sample Document_presentation_version.pdf')
      allow(DerivativeCacheService.instance).to receive(:store_derivative_from_path)

      payload = service.generate_to_cache(pdf_file_set_id: 'pdf-fs-1')

      expect(service).to have_received(:extract_hocr_for_pdf).with(
        '/tmp/pdf_extraction_test/document.pdf',
        '/tmp/pdf_extraction_test',
        'Sample Document_HOCR.hocr'
      )
      expect(service).to have_received(:generate_embedded_text_pdf).with(
        '/tmp/pdf_extraction_test/document.pdf',
        '/tmp/pdf_extraction_test',
        'Sample Document_presentation_version.pdf'
      )
      expect(payload).to eq(
        source_file_set_id: 'pdf-fs-1',
        cache_file_identifier_hocr: 'derivatives:text_extraction_from_pdf:work:work-pdf-1:source:pdf-fs-1:Sample Document_HOCR.hocr',
        cache_filename_hocr: 'Sample Document_HOCR.hocr',
        cache_file_identifier_pdf: 'derivatives:text_extraction_from_pdf:work:work-pdf-1:source:pdf-fs-1:Sample Document_presentation_version.pdf',
        cache_filename_pdf: 'Sample Document_presentation_version.pdf'
      )
    end

    it 'caches a text-preserving presentation PDF when PDF has embedded text' do
      allow(service).to receive(:member_file_sets).and_return([pdf_file_set])
      allow(Dir).to receive(:mktmpdir).and_return('/tmp/pdf_extraction_test')
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with('/tmp/pdf_extraction_test').and_return(true)
      allow(File).to receive(:exist?).with('/tmp/pdf_extraction_test/Sample Document_presentation_version.pdf').and_return(true)
      allow(FileUtils).to receive(:rm_rf)
      allow(service).to receive(:fetch_pdf_file).and_return('/tmp/pdf_extraction_test/document.pdf')
      allow(service).to receive(:pdf_contains_embedded_text?).and_return(true)
      allow(service).to receive(:extract_hocr_for_pdf)
      allow(service).to receive(:generate_text_preserving_presentation_pdf)
        .and_return('/tmp/pdf_extraction_test/Sample Document_presentation_version.pdf')
      allow(DerivativeCacheService.instance).to receive(:store_derivative_from_path)

      payload = service.generate_to_cache(pdf_file_set_id: 'pdf-fs-1')

      expect(service).not_to have_received(:extract_hocr_for_pdf)
      expect(service).to have_received(:generate_text_preserving_presentation_pdf).with(
        '/tmp/pdf_extraction_test/document.pdf',
        '/tmp/pdf_extraction_test',
        'Sample Document_presentation_version.pdf'
      )
      expect(payload).to eq(
        source_file_set_id: 'pdf-fs-1',
        cache_file_identifier_hocr: nil,
        cache_filename_hocr: nil,
        cache_file_identifier_pdf: 'derivatives:text_extraction_from_pdf:work:work-pdf-1:source:pdf-fs-1:Sample Document_presentation_version.pdf',
        cache_filename_pdf: 'Sample Document_presentation_version.pdf'
      )
    end

    it 'returns nil when extraction artifacts are already complete' do
      allow(service).to receive(:member_file_sets).and_return([pdf_file_set])
      allow(service).to receive(:extraction_artifacts_complete_for?).with(pdf_file_set).and_return(true)
      allow(service).to receive(:generate_and_cache_pdf_derivatives)

      payload = service.generate_to_cache(pdf_file_set_id: 'pdf-fs-1')

      expect(service).not_to have_received(:generate_and_cache_pdf_derivatives)
      expect(payload).to be_nil
    end
  end

  describe '#attach_presentation_pdf_to_work' do
    let(:source_pdf_file_set) { pdf_file_set }

    it 'attaches presentation PDF with presentation_version derivative type' do
      user = instance_double('User', user_key: 'depositor@example.edu')
      attached_file_set = instance_double('FileSet')

      allow(User).to receive(:find_by).with(email: work.depositor).and_return(user)
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with('/tmp/presentation.pdf').and_return(true)
      allow(service).to receive(:with_work_lock).and_yield
      allow(service).to receive(:reload_work).and_return(work)
      allow(service).to receive(:find_existing_presentation_pdfs_for_source).and_return([])
      allow(service).to receive(:attach_single_file_to_work).and_return(attached_file_set)
      allow(service).to receive(:reindex_work_and_file_set)
      allow(service).to receive(:cache_derivative)

      service.send(:attach_presentation_pdf_to_work, '/tmp/presentation.pdf', source_pdf_file_set)

      expect(service).to have_received(:attach_single_file_to_work).with(
        file_path: '/tmp/presentation.pdf',
        user: user,
        service_file: true,
        source_file_set: source_pdf_file_set,
        derivative_type_override: Derivatives::FileSetLevel::TextExtraction::FromPdf::DERIVATIVE_TYPE_PRESENTATION_VERSION
      )
    end

    it 'removes all existing presentation PDFs for the same source before attaching replacement' do
      user = instance_double('User', user_key: 'depositor@example.edu')
      old_file_set = instance_double('FileSet')
      older_file_set = instance_double('FileSet')
      attached_file_set = instance_double('FileSet')

      allow(User).to receive(:find_by).with(email: work.depositor).and_return(user)
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with('/tmp/presentation.pdf').and_return(true)
      allow(service).to receive(:with_work_lock).and_yield
      allow(service).to receive(:reload_work).and_return(work)
      allow(service).to receive(:find_existing_presentation_pdfs_for_source).and_return([old_file_set, older_file_set])
      allow(service).to receive(:presentation_pdf_contains_embedded_text?).and_return(false)
      allow(service).to receive(:remove_existing_member_file_set)
      allow(service).to receive(:attach_single_file_to_work).and_return(attached_file_set)
      allow(service).to receive(:reindex_work_and_file_set)
      allow(service).to receive(:cache_derivative)

      service.send(:attach_presentation_pdf_to_work, '/tmp/presentation.pdf', source_pdf_file_set)

      expect(service).to have_received(:remove_existing_member_file_set).with(old_file_set)
      expect(service).to have_received(:remove_existing_member_file_set).with(older_file_set)
    end

    it 'removes existing presentation PDFs for the same source even when filenames differ' do
      user = instance_double('User', user_key: 'depositor@example.edu')
      old_file_set = instance_double('FileSet')
      attached_file_set = instance_double('FileSet')

      allow(User).to receive(:find_by).with(email: work.depositor).and_return(user)
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with('/tmp/presentation.pdf').and_return(true)
      allow(service).to receive(:with_work_lock).and_yield
      allow(service).to receive(:reload_work).and_return(work)
      allow(service).to receive(:find_existing_presentation_pdfs_for_source).and_return([old_file_set])
      allow(service).to receive(:presentation_pdf_contains_embedded_text?).and_return(false)
      allow(service).to receive(:remove_existing_member_file_set)
      allow(service).to receive(:attach_single_file_to_work).and_return(attached_file_set)
      allow(service).to receive(:reindex_work_and_file_set)
      allow(service).to receive(:cache_derivative)

      service.send(:attach_presentation_pdf_to_work, '/tmp/presentation.pdf', source_pdf_file_set)

      expect(service).to have_received(:find_existing_presentation_pdfs_for_source).with(source_pdf_file_set: source_pdf_file_set)
      expect(service).to have_received(:remove_existing_member_file_set).with(old_file_set)
    end

    it 'keeps an existing text-bearing presentation PDF for the same source' do
      user = instance_double('User', user_key: 'depositor@example.edu')
      existing_file_set = instance_double('FileSet')

      allow(User).to receive(:find_by).with(email: work.depositor).and_return(user)
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with('/tmp/presentation.pdf').and_return(true)
      allow(service).to receive(:with_work_lock).and_yield
      allow(service).to receive(:reload_work).and_return(work)
      allow(service).to receive(:find_existing_presentation_pdfs_for_source).and_return([existing_file_set])
      allow(service).to receive(:presentation_pdf_contains_embedded_text?).with(existing_file_set).and_return(true)
      allow(service).to receive(:reindex_work_and_file_set)
      allow(service).to receive(:remove_existing_member_file_set)
      allow(service).to receive(:attach_single_file_to_work)

      result = service.send(:attach_presentation_pdf_to_work, '/tmp/presentation.pdf', source_pdf_file_set)

      expect(result).to eq(existing_file_set)
      expect(service).not_to have_received(:remove_existing_member_file_set)
      expect(service).not_to have_received(:attach_single_file_to_work)
    end

    it 'removes the existing presentation file set from work membership, persistence, and index' do
      deletion_work = Struct.new(:id, :member_ids).new('work-1', ['pdf-1', 'old-presentation'])
      old_file_set = instance_double('FileSet', id: 'old-presentation')
      persister = instance_double('Persister')
      index_adapter = instance_double('IndexAdapter')

      allow(service).to receive(:reload_work).and_return(deletion_work)
      allow(service).to receive(:save_and_index).and_return(deletion_work)
      allow(Hyrax).to receive(:persister).and_return(persister)
      allow(Hyrax).to receive(:index_adapter).and_return(index_adapter)
      allow(persister).to receive(:delete)
      allow(index_adapter).to receive(:delete)

      service.send(:remove_existing_member_file_set, old_file_set)

      expect(deletion_work.member_ids).to eq(['pdf-1'])
      expect(service).to have_received(:save_and_index).with(deletion_work)
      expect(persister).to have_received(:delete).with(resource: old_file_set)
      expect(index_adapter).to have_received(:delete).with(resource: old_file_set)
    end
  end

  describe '#pdf_contains_embedded_text?' do
    let(:success_status) { instance_double(Process::Status, success?: true) }
    let(:failed_status) { instance_double(Process::Status, success?: false) }

    it 'returns true for significant embedded text content' do
      allow(Open3).to receive(:capture3).and_return(['This PDF includes enough embedded readable text to skip OCR generation.', '', success_status])

      expect(service.send(:pdf_contains_embedded_text?, '/tmp/document.pdf')).to be(true)
      expect(Open3).to have_received(:capture3).with(
        'pdftotext', '-q', '-f', '1', '-l', '5', '/tmp/document.pdf', '-'
      )
    end

    it 'returns false when pdftotext fails' do
      allow(Open3).to receive(:capture3).and_return(['', 'error', failed_status])

      expect(service.send(:pdf_contains_embedded_text?, '/tmp/document.pdf')).to be(false)
    end
  end

  describe '#significant_embedded_text?' do
    it 'returns false for short or mostly non-alpha content' do
      expect(service.send(:significant_embedded_text?, '1234 5678 --')).to be(false)
      expect(service.send(:significant_embedded_text?, 'short text')).to be(false)
    end

    it 'returns true for substantial alpha-rich content' do
      text = 'This searchable PDF contains a meaningful amount of embedded textual content for discovery and accessibility.'

      expect(service.send(:significant_embedded_text?, text)).to be(true)
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

  describe '#concatenate_pdfs_for_presentation' do
    let(:page_pdf_paths) { ['/tmp/pdf/page_0001.pdf', '/tmp/pdf/page_0002.pdf'] }
    let(:output_path) { '/tmp/pdf/output.pdf' }

    it 'prefers pdfunite when available and successful' do
      success_status = instance_double(Process::Status, success?: true, exitstatus: 0)
      allow(Open3).to receive(:capture3).with('pdfunite', *page_pdf_paths, output_path)
                                    .and_return(['', '', success_status])
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(output_path).and_return(true)
      allow(Open3).to receive(:capture3).with('gs', anything, anything, anything, anything, anything, anything, anything)

      service.send(:concatenate_pdfs_for_presentation, page_pdf_paths, output_path)

      expect(Open3).to have_received(:capture3).with('pdfunite', *page_pdf_paths, output_path)
      expect(Open3).not_to have_received(:capture3).with(
        'gs',
        '-dBATCH',
        '-dNOPAUSE',
        '-sDEVICE=pdfwrite',
        '-dCompatibilityLevel=1.4',
        "-sOutputFile=#{output_path}",
        *page_pdf_paths
      )
    end

    it 'falls back to ghostscript when pdfunite is unavailable' do
      success_status = instance_double(Process::Status, success?: true, exitstatus: 0)
      allow(Open3).to receive(:capture3).with('pdfunite', *page_pdf_paths, output_path)
                                    .and_raise(Errno::ENOENT)
      allow(Open3).to receive(:capture3).with(
        'gs',
        '-dBATCH',
        '-dNOPAUSE',
        '-sDEVICE=pdfwrite',
        '-dCompatibilityLevel=1.4',
        "-sOutputFile=#{output_path}",
        *page_pdf_paths
      ).and_return(['', '', success_status])

      service.send(:concatenate_pdfs_for_presentation, page_pdf_paths, output_path)

      expect(Open3).to have_received(:capture3).with('pdfunite', *page_pdf_paths, output_path)
      expect(Open3).to have_received(:capture3).with(
        'gs',
        '-dBATCH',
        '-dNOPAUSE',
        '-sDEVICE=pdfwrite',
        '-dCompatibilityLevel=1.4',
        "-sOutputFile=#{output_path}",
        *page_pdf_paths
      )
    end
  end

end
