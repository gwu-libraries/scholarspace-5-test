require 'rails_helper'

RSpec.describe WorkViewerHelper, type: :helper do
  describe '#hocr_download_url_for_work' do
    let(:presenter) { instance_double('Presenter', id: 'work-1', member_ids: %w[pdf-1 hocr-1]) }
    let(:pdf_file_set) do
      instance_double(
        'PdfFileSet',
        id: 'pdf-1',
        original_file: instance_double('OriginalFile', original_filename: nil, mime_type: 'application/pdf'),
        label: 'Sample Document.pdf',
        title: ['Sample Document.pdf']
      )
    end
    let(:hocr_file_set) do
      instance_double(
        'HocrFileSet',
        id: 'hocr-1',
        original_file: instance_double('OriginalFile', original_filename: nil),
        label: 'custom-name.hocr',
        title: ['custom-name.hocr'],
        related_url: ['source_file_set_id:pdf-1']
      )
    end

    before do
      helper.define_singleton_method(:download_path) do |id:, locale:|
        "/downloads/#{id}?locale=#{locale.inspect}"
      end
      allow(Hyrax.query_service).to receive(:find_by).with(id: 'pdf-1').and_return(pdf_file_set)
      allow(Hyrax.query_service).to receive(:find_by).with(id: 'hocr-1').and_return(hocr_file_set)
    end

    it 'finds the hocr file by source metadata linkage when original_filename is blank' do
      expect(helper.hocr_download_url_for_work(presenter, pdf_file_id: 'pdf-1')).to eq('/downloads/hocr-1?locale=nil')
    end
  end
end
