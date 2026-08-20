# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FullTextIndexable do
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
      include FullTextIndexable
    end
  end

  let(:resource) { instance_double('Resource') }
  let(:index_document) { {} }
  let(:indexer) { indexer_class.new(resource: resource, index_document: index_document) }

  before do
    allow(resource).to receive(:member_ids).and_return([])
  end

  it 'indexes text embedded in attached PDF files' do
    file = double('file', original_filename: 'source.pdf', file_identifier: 'fid-pdf')
    member = instance_double('Member', original_file: file)
    stored_file = instance_double('StoredFile', stream: StringIO.new('%PDF embedded text'))
    success_status = instance_double(Process::Status, success?: true)

    allow(resource).to receive(:member_ids).and_return(['member-1'])
    allow(Hyrax).to receive(:query_service).and_return(instance_double('QueryService', find_by: member))
    allow(Hyrax).to receive(:storage_adapter).and_return(instance_double('StorageAdapter', find_by: stored_file))
    allow(Open3).to receive(:capture3).and_return(['This PDF contains QGIS searchable text.', '', success_status])

    indexed_values = indexer.to_solr[:all_text_tsimv]

    expect(indexed_values.join(' ')).to include('QGIS searchable text')
    expect(Open3).to have_received(:capture3).with('pdftotext', '-q', kind_of(String), '-')
  end

  it 'indexes trailing full-text content beyond the former aggregate limit' do
    trailing_token = 'tailtokensearchable'
    full_text = "#{Array.new(30) { |page| "page#{page} #{'indexed ' * 600}" }.join(' ')} #{trailing_token}"

    allow(indexer).to receive(:extract_full_text_content).and_return(full_text)

    indexed_values = indexer.to_solr[:all_text_tsimv]

    expect(indexed_values.join(' ')).to include(trailing_token)
    expect(indexed_values).to all(have_attributes(length: be <= described_class::MAX_INDEX_VALUE_CHARS))
  end

  it 'splits oversized tokens into Solr-safe indexed values without dropping text' do
    long_token = 'x' * (described_class::MAX_INDEX_VALUE_CHARS * 2 + 100)

    allow(indexer).to receive(:extract_full_text_content).and_return(long_token)

    indexed_values = indexer.to_solr[:all_text_tsimv]

    expect(indexed_values.join).to eq(long_token)
    expect(indexed_values).to all(have_attributes(length: be <= described_class::MAX_INDEX_VALUE_CHARS))
  end

  it 'preserves existing all_text values while appending full text' do
    existing_token = 'existingsearchable'
    appended_token = 'appendedsearchable'
    index_document[:all_text_tsimv] = [existing_token]

    allow(indexer).to receive(:extract_full_text_content).and_return(appended_token)

    expect(indexer.to_solr[:all_text_tsimv].join(' ')).to include(existing_token, appended_token)
  end
end