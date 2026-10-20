# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FileSetIndexer do
  subject(:indexer) { described_class.allocate }

  describe 'full-text extraction' do
    it 'indexes VTT dialogue without cue identifiers, timestamps, or notes' do
      content = "WEBVTT\n\nNOTE internal note\nignored\n\n1\n00:00:01.000 --> 00:00:04.000\nHello world\n"
      file = double('file', original_filename: 'captions.VTT')

      expect(indexer.send(:plain_text_for_file, file, content)).to eq('Hello world')
    end

    it 'indexes hOCR words and preserves the original markup' do
      content = '<html><body><span class="ocrx_word">Searchable</span> <span class="ocr_word">text</span></body></html>'
      file = double('file', original_filename: 'scan.hocr')

      expect(indexer.send(:plain_text_for_file, file, content)).to eq('Searchable text')
      expect(indexer.send(:hocr_markup_for_file, file, content)).to eq(content)
    end

    it 'indexes PDF text returned by pdftotext' do
      file = double('file', original_filename: 'document.pdf')
      allow(Open3).to receive(:capture3).and_return(["PDF\ntext", '', instance_double(Process::Status, success?: true)])

      expect(indexer.send(:plain_text_for_file, file, 'pdf bytes')).to eq('PDF text')
      expect(Open3).to have_received(:capture3).with('pdftotext', '-q', anything, '-')
    end

    it 'ignores unsupported files and empty content' do
      file = double('file', original_filename: 'photo.png')

      expect(indexer.send(:plain_text_for_file, file, 'pixels')).to be_nil
      expect(indexer.send(:plain_text_for_file, file, '')).to be_nil
    end
  end
end