# frozen_string_literal: true

require "rails_helper"

RSpec.describe OcrTextIndexable do
  let(:base_indexer_class) do
    Class.new do
      attr_reader :resource

      def initialize(resource:, index_document: {})
        @resource = resource
        @index_document = index_document
      end

      def to_solr
        @index_document.dup
      end
    end
  end

  let(:indexer_class) do
    Class.new(base_indexer_class) do
      include OcrTextIndexable
    end
  end

  let(:resource) { instance_double("Resource", member_ids: ["hocr-member-1"]) }
  let(:indexer) { indexer_class.new(resource: resource) }
  let(:file) { double("OriginalFile", original_filename: "page_0001.hocr", file_identifier: "file-1") }
  let(:member) { double("FileSet", original_file: file) }

  it "indexes an OCR highlighting pointer for HOCR member files" do
    allow(Hyrax.query_service).to receive(:find_by).with(id: "hocr-member-1").and_return(member)
    allow(indexer).to receive(:ocr_pointer_root).and_return("/tmp/ocr-cache")
    allow(indexer).to receive(:copy_file_to_disk).and_return("/tmp/ocr-cache/copied.hocr")

    solr_document = indexer.to_solr

    expect(solr_document[:ocr_text]).to match(%r{\A/tmp/ocr-cache/[a-f0-9]{64}\.hocr\z})
  end

  it "does not index the reading mode HOCR sidecar as an OCR source pointer" do
    reading_mode_file = double("OriginalFile", original_filename: Constants::DerivativeFilenameConstants::READING_MODE_HOCR_FILENAME)
    reading_mode_member = double("FileSet", original_file: reading_mode_file)

    allow(Hyrax.query_service).to receive(:find_by).with(id: "hocr-member-1").and_return(reading_mode_member)

    expect(indexer.to_solr).not_to have_key(:ocr_text)
  end
end