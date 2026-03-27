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

    it 'creates a base PDF and then OCR-processes it into rendering PDF' do
      allow(Open3).to receive(:capture3).and_return(['', '', instance_double(Process::Status, success?: true)])

      service.join_images_to_pdf(image_paths)

      expect(Open3).to have_received(:capture3).with('magick', 'convert', *image_paths, '/tmp/workdir/pdfs/joined_images_derivative_raw.pdf')
      expect(Open3).to have_received(:capture3).with(
        'ocrmypdf',
        '--skip-text',
        '--optimize', '1',
        '/tmp/workdir/pdfs/joined_images_derivative_raw.pdf',
        '/tmp/workdir/pdfs/joined_images_derivative_OCR_RENDERING.pdf'
      )
      expect(service.instance_variable_get(:@joined_pdf_path)).to eq('/tmp/workdir/pdfs/joined_images_derivative_OCR_RENDERING.pdf')
    end
  end

  describe '#joined_pdf_filename' do
    it 'uses OCR rendering suffix so viewer prefers this derivative' do
      expect(service.joined_pdf_filename).to eq('joined_images_derivative_OCR_RENDERING.pdf')
    end
  end
end
