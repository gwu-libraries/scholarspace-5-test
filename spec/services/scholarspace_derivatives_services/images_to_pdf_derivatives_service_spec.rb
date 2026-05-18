# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ScholarspaceDerivativesServices::ImagesToPdfDerivativesService do
  subject(:service) { described_class.new(work) }

  let(:work) { instance_double('Work', id: 'work-2') }

  describe '#join_images_to_pdf' do
    let(:image_paths) { ['/tmp/0001.jpg', '/tmp/0002.jpg'] }

    before do
      service.instance_variable_set(:@working_dir, '/tmp/workdir')
      allow(Dir).to receive(:mkdir)
    end

    it 'creates the joined PDF directly from source images' do
      allow(Open3).to receive(:capture3).and_return(['', '', instance_double(Process::Status, success?: true)])

      service.join_images_to_pdf(image_paths)

      expect(Open3).to have_received(:capture3).with(
        'magick',
        'convert',
        *image_paths,
        '/tmp/workdir/pdfs/joined_images_pdf.pdf'
      )
      expect(service.instance_variable_get(:@joined_pdf_path)).to eq('/tmp/workdir/pdfs/joined_images_pdf.pdf')
    end
  end

  describe '#build_joined_hocr_file' do
    let(:image_derivatives) do
      [
        { hocr_path: '/tmp/workdir/hocr/page_1_HOCR.hocr' },
        { hocr_path: '/tmp/workdir/hocr/page_2_HOCR.hocr' }
      ]
    end

    it 'delegates merged HOCR creation to HocrMergeable' do
      allow(service).to receive(:merge_hocr_files).and_return('/tmp/workdir/hocr/joined_images_pdf_HOCR.hocr')

      result = service.send(:build_joined_hocr_file, image_derivatives)

      expect(service).to have_received(:merge_hocr_files).with([
        '/tmp/workdir/hocr/page_1_HOCR.hocr',
        '/tmp/workdir/hocr/page_2_HOCR.hocr'
      ])
      expect(result).to eq('/tmp/workdir/hocr/joined_images_pdf_HOCR.hocr')
    end
  end

  describe '#attach_joined_hocr_to_work' do
    it 'attaches the joined HOCR sidecar to the work' do

      allow(service).to receive(:build_joined_hocr_file).and_return('/tmp/workdir/hocr/joined_images_pdf_HOCR.hocr')
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with('/tmp/workdir/hocr/joined_images_pdf_HOCR.hocr').and_return(true)
      allow(service).to receive(:depositor).and_return(instance_double('User'))
      allow(service).to receive(:file_set_attached_with_name?).with('joined_images_pdf_HOCR.hocr').and_return(false)
      allow(service).to receive(:source_image_file_sets).and_return([instance_double('FileSet')])
      allow(service).to receive(:attach_file_to_work)

      service.send(:attach_joined_hocr_to_work, [{ hocr_path: '/tmp/workdir/hocr/page_1_HOCR.hocr' }])

      expect(service).to have_received(:attach_file_to_work).with('/tmp/workdir/hocr/joined_images_pdf_HOCR.hocr', source_file_set: anything)
    end
  end

  describe '#joined_pdf_filename' do
    it 'uses the joined_images_pdf naming convention' do
      expect(service.joined_pdf_filename).to eq('joined_images_pdf.pdf')
    end
  end
end
