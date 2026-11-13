# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkMemberFileSetQueries do
  let(:work_class) do
    Class.new do
      include WorkMemberFileSetQueries

      attr_accessor :member_ids

      def initialize(member_ids: [])
        @member_ids = member_ids
      end
    end
  end

  let(:file_set_a) { double('FileSet', id: 'fs-a', service_file: false) }
  let(:file_set_b) { double('FileSet', id: 'fs-b', service_file: true) }
  let(:work) { work_class.new(member_ids: %w[fs-a fs-b]) }

  before do
    allow(Hyrax.query_service).to receive(:find_by).with(id: 'fs-a').and_return(file_set_a)
    allow(Hyrax.query_service).to receive(:find_by).with(id: 'fs-b').and_return(file_set_b)
  end

  describe '#member_file_sets' do
    it 'returns the member file sets' do
      expect(work.member_file_sets).to eq([file_set_a, file_set_b])
    end

    it 'queries each member only once across repeated calls' do
      3.times { work.member_file_sets }

      expect(Hyrax.query_service).to have_received(:find_by).with(id: 'fs-a').once
      expect(Hyrax.query_service).to have_received(:find_by).with(id: 'fs-b').once
    end

    it 're-queries when member_ids changes so the cache cannot go stale' do
      work.member_file_sets
      work.member_ids = ['fs-a']

      expect(work.member_file_sets).to eq([file_set_a])
      expect(Hyrax.query_service).to have_received(:find_by).with(id: 'fs-a').twice
    end

    it 'skips members that are no longer found' do
      allow(Hyrax.query_service).to receive(:find_by).with(id: 'fs-b')
                                                    .and_raise(Valkyrie::Persistence::ObjectNotFoundError)

      expect(work.member_file_sets).to eq([file_set_a])
    end
  end

  describe '#original_member_file_sets' do
    it 'excludes service files without issuing additional queries' do
      work.member_file_sets

      expect(work.original_member_file_sets).to eq([file_set_a])
      expect(Hyrax.query_service).to have_received(:find_by).with(id: 'fs-a').once
    end
  end
end
