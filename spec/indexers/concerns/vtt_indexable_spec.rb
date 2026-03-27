# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VttIndexable do
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
      include VttIndexable
    end
  end

  let(:query_service) { instance_double('QueryService') }
  let(:storage_adapter) { instance_double('StorageAdapter') }

  before do
    allow(Hyrax).to receive(:query_service).and_return(query_service)
    allow(Hyrax).to receive(:storage_adapter).and_return(storage_adapter)
  end

  it 'adds normalized transcript text for attached VTT files' do
    file = double('file', original_filename: 'speech.vtt', file_identifier: 'fid-vtt')
    member = instance_double('Member', original_file: file)
    io = instance_double(
      'StoredFile',
      stream: StringIO.new(
        "WEBVTT\n\n1\n00:00:00.000 --> 00:00:01.000 align:start position:0%\nhello\n\n" \
        "NOTE this is metadata\nnot transcript\n\n" \
        "2\n00:00:01.000 --> 00:00:02.000\nworld"
      )
    )

    allow(query_service).to receive(:find_by).with(id: 'member-1').and_return(member)
    allow(storage_adapter).to receive(:find_by).with(id: 'fid-vtt').and_return(io)

    expect(indexer.to_solr[:vtt_text_tesim]).to eq('hello world')
  end

  it 'does not add vtt_text when no VTT files are present' do
    file = double('file', original_filename: 'audio.wav', file_identifier: 'fid-audio')
    member = instance_double('Member', original_file: file)

    allow(query_service).to receive(:find_by).with(id: 'member-1').and_return(member)

    expect(indexer.to_solr).not_to have_key(:vtt_text_tesim)
  end

  it 'raises when members are missing' do
    allow(query_service).to receive(:find_by).with(id: 'member-1').and_raise(Valkyrie::Persistence::ObjectNotFoundError)

    expect { indexer.to_solr }.to raise_error(Valkyrie::Persistence::ObjectNotFoundError)
  end

  it 'raises when stored files are missing' do
    file = double('file', original_filename: 'speech.vtt', file_identifier: 'fid-vtt')
    member = instance_double('Member', original_file: file)

    allow(query_service).to receive(:find_by).with(id: 'member-1').and_return(member)
    allow(storage_adapter).to receive(:find_by).with(id: 'fid-vtt').and_raise(Valkyrie::Persistence::ObjectNotFoundError)

    expect { indexer.to_solr }.to raise_error(Valkyrie::Persistence::ObjectNotFoundError)
  end
end