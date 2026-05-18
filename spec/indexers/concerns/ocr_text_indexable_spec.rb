# frozen_string_literal: true

require 'rails_helper'
require 'tmpdir'

RSpec.describe OcrTextIndexable do
  subject(:indexer) { indexer_class.new(resource: resource) }

  let(:hocr_content) do
    <<~HOCR
      <html>
        <body>
          <div class="ocr_page">
            <span class="ocrx_word">alpha</span>
            <span class="ocrx_word">ocr</span>
            <span class="ocrx_word">text</span>
          </div>
        </body>
      </html>
    HOCR
  end

  let(:resource) { instance_double('Resource', member_ids: member_ids) }
  let(:member_ids) { ['member-1'] }

  # this pattern below is a way of testing rails mix-in modules.
  # they should be indifferent to what class is including them, so we 
  # just use Class.new to create a minimal class to include just the module

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
      include OcrTextIndexable
    end
  end

  let(:query_service) { instance_double('QueryService') }
  let(:storage_adapter) { instance_double('StorageAdapter') }
  let(:tmp_dir) { Dir.mktmpdir }

  before do
    allow(Hyrax).to receive(:query_service).and_return(query_service)
    allow(Hyrax).to receive(:storage_adapter).and_return(storage_adapter)
    allow(indexer).to receive(:ocr_pointer_root).and_return(tmp_dir)
  end

  after do
    FileUtils.remove_entry(tmp_dir)
  end

  it 'adds ocr_text source pointer for attached hOCR files' do
    file = double('file', original_filename: 'page_0001_HOCR.hocr', file_identifier: 'fid-1')
    member = instance_double('Member', original_file: file)
    io = instance_double('StoredFile', stream: StringIO.new(hocr_content))

    allow(query_service).to receive(:find_by).with(id: 'member-1').and_return(member)
    allow(storage_adapter).to receive(:find_by).with(id: 'fid-1').and_return(io)

    solr_document = indexer.to_solr
    pointer = solr_document[:ocr_text]

    expect(pointer).to start_with(tmp_dir)
    expect(pointer).to end_with('.hocr')
    expect(File.read(pointer)).to eq(hocr_content)
  end

  it 'does not add ocr_text when no hOCR files are present' do
    file = double('file', original_filename: 'source.pdf', file_identifier: 'fid-2')
    member = instance_double('Member', original_file: file)

    allow(query_service).to receive(:find_by).with(id: 'member-1').and_return(member)

    expect(indexer.to_solr).not_to have_key(:ocr_text)
  end

  it 'skips missing members' do
    allow(query_service).to receive(:find_by).with(id: 'member-1').and_raise(Valkyrie::Persistence::ObjectNotFoundError)

    expect(indexer.to_solr).not_to have_key(:ocr_text)
  end

  it 'skips missing stored files' do
    file = double('file', original_filename: 'page_0001_HOCR.hocr', file_identifier: 'fid-1')
    member = instance_double('Member', original_file: file)

    allow(query_service).to receive(:find_by).with(id: 'member-1').and_return(member)
    allow(indexer).to receive(:find_storage_file_by_id).with('fid-1').and_return(nil)

    expect(indexer.to_solr).not_to have_key(:ocr_text)
  end
end