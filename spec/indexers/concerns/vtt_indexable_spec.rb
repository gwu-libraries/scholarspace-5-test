# frozen_string_literal: true

require "rails_helper"
require "stringio"

RSpec.describe VttIndexable do
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
      include VttIndexable
    end
  end

  let(:resource) { instance_double("Resource", member_ids: ["vtt-member-1"]) }
  let(:indexer) { indexer_class.new(resource: resource) }
  let(:file) { double("OriginalFile", original_filename: "lecture.vtt", file_identifier: "file-1") }
  let(:member) { double("FileSet", original_file: file) }
  let(:storage_file) { double("StorageFile", stream: StringIO.new(vtt_content)) }
  let(:vtt_content) do
    "WEBVTT\n\n" \
      "cue-1\n" \
      "00:00:00.000 --> 00:00:02.000\n" \
      "Hello from transcript\n"
  end

  it "indexes normalized transcript text from VTT member files" do
    allow(Hyrax.query_service).to receive(:find_by).with(id: "vtt-member-1").and_return(member)
    allow(Hyrax.storage_adapter).to receive(:find_by).with(id: "file-1").and_return(storage_file)

    expect(indexer.to_solr[:vtt_text_tesim]).to eq("Hello from transcript")
  end
end