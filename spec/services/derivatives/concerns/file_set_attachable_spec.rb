# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Derivatives::Concerns::FileSetAttachable do
  let(:test_class) do
    Class.new do
      include Derivatives::Concerns::FileSetAttachable

      attr_accessor :work

      def initialize(work)
        @work = work
      end
    end
  end

  let(:work_id) { "attach-test-work-#{SecureRandom.hex(4)}" }

  let(:work_class) do
    Class.new do
      attr_accessor :id, :member_ids, :representative_id, :thumbnail_id

      def initialize(id:, member_ids: [])
        @id = id
        @member_ids = member_ids
      end
    end
  end

  let(:work) { work_class.new(id: work_id) }
  let(:file_set) { double('FileSet', id: 'fs-1') }
  let(:service) { test_class.new(work) }
  # Valkyrie's memory-adapter MetadataAdapter#persister builds a new instance on
  # every call (no memoization), so stub Hyrax.persister itself to return one
  # stable double rather than stubbing whatever instance it happens to return once.
  let(:persister) { instance_double(Valkyrie::Persistence::Memory::Persister) }

  describe '#attach_file_set_to_work' do
    before do
      allow(Hyrax.query_service).to receive(:find_by).with(id: work_id).and_return(work)
      allow(Hyrax).to receive(:persister).and_return(persister)
      allow(persister).to receive(:save).with(resource: work).and_return(work)
      allow(service).to receive(:reindex_file_set)
      allow(service).to receive(:schedule_work_reindex)
    end

    it 'appends the file set id, sets representative/thumbnail, and saves once' do
      service.attach_file_set_to_work(file_set)

      expect(work.member_ids).to eq(['fs-1'])
      expect(work.representative_id).to eq('fs-1')
      expect(work.thumbnail_id).to eq('fs-1')
      expect(persister).to have_received(:save).with(resource: work).once
      expect(service).to have_received(:reindex_file_set).with(file_set).once
    end

    it 'does not re-save when the file set id is already a member' do
      work.member_ids = ['fs-1']
      work.representative_id = 'fs-1'
      work.thumbnail_id = 'fs-1'

      service.attach_file_set_to_work(file_set)

      expect(persister).not_to have_received(:save)
    end

    it 'lets a conflicting concurrent write raise for the job-level retry policy to handle' do
      allow(persister).to receive(:save).with(resource: work)
                                        .and_raise(Valkyrie::Persistence::StaleObjectError)

      expect { service.attach_file_set_to_work(file_set) }.to raise_error(Valkyrie::Persistence::StaleObjectError)
    end
  end

  describe '#member_solr_documents' do
    it 'queries Solr over POST so large member lists cannot overrun the URI limit' do
      work.member_ids = Array.new(400) { |i| "fs-#{i}" }
      allow(Hyrax::SolrService).to receive(:post).and_return({ 'response' => { 'docs' => [] } })

      service.member_solr_documents

      expect(Hyrax::SolrService).to have_received(:post)
      expect(Hyrax::SolrService).not_to receive(:get)
    end

    it 'returns no documents and issues no query when the work has no members' do
      allow(Hyrax::SolrService).to receive(:post)

      expect(service.member_solr_documents).to eq([])
      expect(Hyrax::SolrService).not_to have_received(:post)
    end

    it 'caches results per member_ids and re-queries when membership changes' do
      work.member_ids = ['fs-1']
      allow(Hyrax::SolrService).to receive(:post).and_return({ 'response' => { 'docs' => [] } })

      2.times { service.member_solr_documents }
      expect(Hyrax::SolrService).to have_received(:post).once

      work.member_ids = %w[fs-1 fs-2]
      service.member_solr_documents
      expect(Hyrax::SolrService).to have_received(:post).twice
    end
  end
end
