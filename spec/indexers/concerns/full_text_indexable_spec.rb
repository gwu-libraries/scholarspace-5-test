# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FullTextIndexable do
  subject(:indexer) { indexer_class.new(resource: resource) }

  let(:resource) { instance_double('Resource', member_ids: member_ids) }
  let(:member_ids) { ['member-1'] }

  let(:base_indexer_class) do
    Class.new do
      attr_reader :resource

      def initialize(resource:)
        @resource = resource
      end

      def to_solr
        { id: resource.object_id }
      end
    end
  end

  let(:indexer_class) do
    Class.new(base_indexer_class) do
      include FullTextIndexable
    end
  end

  let(:query_service) { instance_double('QueryService') }
  let(:storage_adapter) { instance_double('StorageAdapter') }
  let(:custom_queries) { instance_double('CustomQueries') }

  before do
    allow(Hyrax).to receive(:query_service).and_return(query_service)
    allow(Hyrax).to receive(:storage_adapter).and_return(storage_adapter)
    allow(Hyrax).to receive(:custom_queries).and_return(custom_queries)
  end

  it 'indexes normalized plain text from attached hOCR files' do
    file = double('file', original_filename: 'page_0001_HOCR.hocr', file_identifier: 'fid-hocr')
    member = instance_double('Member', original_file: file, extracted_text_id: nil)
    io = instance_double('StoredFile', stream: StringIO.new('<html><body><span class="ocrx_word">ofﬁce</span><span class="ocrx_word"> ﬂight </span></body></html>'))

    allow(query_service).to receive(:find_by).with(id: 'member-1').and_return(member)
    allow(storage_adapter).to receive(:find_by).with(id: 'fid-hocr').and_return(io)

    expect(indexer.to_solr[:all_text_tsimv]).to eq(['office flight'])
  end

  it 'does not index plain text from attached VTT files' do
    file = double('file', original_filename: 'speech.vtt', file_identifier: 'fid-vtt')
    member = instance_double('Member', original_file: file, extracted_text_id: nil)
    io = instance_double('StoredFile', stream: StringIO.new("WEBVTT\n\n1\n00:00:00.000 --> 00:00:01.000\nhello\n\n2\n00:00:01.000 --> 00:00:02.000\nworld"))

    allow(query_service).to receive(:find_by).with(id: 'member-1').and_return(member)
    allow(storage_adapter).to receive(:find_by).with(id: 'fid-vtt').and_return(io)

    expect(indexer.to_solr).not_to have_key(:all_text_tsimv)
  end

  it 'indexes extracted text attached to a member file set' do
    file = double('file', original_filename: 'document.pdf', file_identifier: 'fid-pdf')
    member = instance_double('Member', original_file: file, extracted_text_id: 'extracted-text-1')
    io = instance_double('StoredFile', stream: StringIO.new('%PDF fake content'))
    extracted_text = instance_double('ExtractedText', content: "alpha\n beta\t gamma")

    allow(query_service).to receive(:find_by).with(id: 'member-1').and_return(member)
    allow(storage_adapter).to receive(:find_by).with(id: 'fid-pdf').and_return(io)
    allow(custom_queries).to receive(:find_extracted_text).with(file_set: member).and_return(extracted_text)

    expect(indexer.to_solr[:all_text_tsimv]).to eq(['alpha beta gamma'])
  end

  it 'chunks long plain text into safe index values' do
    file = double('file', original_filename: 'document.pdf', file_identifier: 'fid-pdf')
    member = instance_double('Member', original_file: file, extracted_text_id: 'extracted-text-1')
    io = instance_double('StoredFile', stream: StringIO.new('%PDF fake content'))
    long_text = (['magazine'] * 1200).join(' ')
    extracted_text = instance_double('ExtractedText', content: long_text)

    allow(query_service).to receive(:find_by).with(id: 'member-1').and_return(member)
    allow(storage_adapter).to receive(:find_by).with(id: 'fid-pdf').and_return(io)
    allow(custom_queries).to receive(:find_extracted_text).with(file_set: member).and_return(extracted_text)

    values = indexer.to_solr[:all_text_tsimv]

    expect(values.length).to be > 1
    expect(values).to all(satisfy { |value| value.length <= FullTextIndexable::MAX_INDEX_VALUE_CHARS })
    expect(values.join(' ')).to eq(long_text)
  end

  context 'when the base indexer already supplies all_text_tsimv' do
    let(:base_indexer_class) do
      Class.new do
        attr_reader :resource

        def initialize(resource:)
          @resource = resource
        end

        def to_solr
          { id: resource.object_id, all_text_tsimv: ['existing text'] }
        end
      end
    end

    it 'appends extracted full text instead of replacing existing all_text values' do
      file = double('file', original_filename: 'page_0001_HOCR.hocr', file_identifier: 'fid-hocr')
      member = instance_double('Member', original_file: file, extracted_text_id: nil)
      io = instance_double('StoredFile', stream: StringIO.new('<html><body><span class="ocrx_word">hello</span></body></html>'))

      allow(query_service).to receive(:find_by).with(id: 'member-1').and_return(member)
      allow(storage_adapter).to receive(:find_by).with(id: 'fid-hocr').and_return(io)

      expect(indexer.to_solr[:all_text_tsimv]).to eq(['existing text', 'hello'])
    end
  end
end