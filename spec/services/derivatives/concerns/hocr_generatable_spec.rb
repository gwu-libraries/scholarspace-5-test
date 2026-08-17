# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Derivatives::Concerns::TextExtraction::HocrGeneratable do
  let(:test_class) do
    Class.new do
      include Derivatives::Concerns::TextExtraction::HocrGeneratable
    end
  end

  subject(:service) { test_class.new }

  let(:fake_success) { instance_double(Process::Status, success?: true) }
  let(:fake_failure) { instance_double(Process::Status, success?: false) }

  describe '#generate_hocr_file' do
    let(:image_path) { '/tmp/test_page_0001.jpg' }
    let(:output_hocr_path) { '/tmp/test_page_0001_HOCR.hocr' }
    let(:output_base) { '/tmp/test_page_0001_HOCR' }

    it 'calls tesseract with the correct arguments and returns the hOCR output path' do
      allow(Open3).to receive(:capture3)
        .with('tesseract', image_path, output_base, 'hocr')
        .and_return(['', '', fake_success])

      result = service.send(:generate_hocr_file,
                            image_path: image_path,
                            output_hocr_path: output_hocr_path,
                            error_message: 'hOCR generation failed')

      expect(result).to eq(output_hocr_path)
    end

    it 'raises an error containing the error_message when tesseract fails' do
      allow(Open3).to receive(:capture3)
        .with('tesseract', image_path, output_base, 'hocr')
        .and_return(['', 'Error, could not initialize tesseract', fake_failure])

      expect {
        service.send(:generate_hocr_file,
                     image_path: image_path,
                     output_hocr_path: output_hocr_path,
                     error_message: 'hOCR generation failed')
      }.to raise_error(RuntimeError, /hOCR generation failed/)
    end
  end
end
