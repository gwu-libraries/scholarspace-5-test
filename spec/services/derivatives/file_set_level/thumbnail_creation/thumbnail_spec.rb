# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Derivatives::FileSetLevel::ThumbnailCreation::Thumbnail do
  subject(:service) { described_class.new(work) }

  let(:source_original_file) do
    instance_double('OriginalFile', mime_type: 'image/jpeg', original_filename: 'source.jpg')
  end
  let(:source_file_set) do
    instance_double('FileSet', id: 'source-1', original_file: source_original_file, image?: true)
  end
  let(:work) do
    instance_double(
      'Work',
      id: 'work-1',
      depositor: 'depositor@example.edu',
      original_member_file_sets: [source_file_set],
      member_file_sets: []
    )
  end
  let(:depositor) { instance_double('User') }
  let(:cache_service) { instance_double(DerivativeCacheService) }

  before do
    allow(User).to receive(:find_by).with(email: 'depositor@example.edu').and_return(depositor)
    allow(DerivativeCacheService).to receive(:instance).and_return(cache_service)
    allow(Derivatives::FileSetLevel::ThumbnailCreation::FromImage).to receive(:supported_file_set?).with(source_file_set).and_return(true)
  end

  describe '#generate_to_cache' do
    it 'generates and stores a thumbnail cache payload for the requested source file set' do
      Tempfile.create(['source-thumbnail', '.jpg']) do |file|
        file.write('thumbnail bytes')
        file.rewind

        generator = instance_double(
          Derivatives::FileSetLevel::ThumbnailCreation::FromImage,
          thumbnail_filename_for: 'source_thumbnail.jpg',
          generate_thumbnail_asset: file.path
        )
        allow(Derivatives::FileSetLevel::ThumbnailCreation::FromImage).to receive(:new).with(work, working_dir: kind_of(String)).and_return(generator)
        allow(cache_service).to receive(:store_derivative_from_path)

        payload = service.generate_to_cache(source_file_set_id: 'source-1')

        expect(cache_service).to have_received(:store_derivative_from_path).with(
          file_identifier: 'derivatives:thumbnail:work:work-1:source:source-1:source_thumbnail.jpg',
          original_filename: 'source_thumbnail.jpg',
          source_path: file.path,
          derivative_type: 'thumbnail'
        )
        expect(payload).to eq(
          source_file_set_id: 'source-1',
          cache_file_identifier: 'derivatives:thumbnail:work:work-1:source:source-1:source_thumbnail.jpg',
          cache_filename: 'source_thumbnail.jpg'
        )
      end
    end
  end

  describe '#persist_from_cache' do
    it 'fetches cached thumbnail content and attaches it to the source file set' do
      cached_io = StringIO.new('thumbnail bytes')
      allow(cache_service).to receive(:fetch_stream).and_return(cached_io)
      allow(service).to receive(:attach_single_file_to_work)

      service.persist_from_cache(
        source_file_set_id: 'source-1',
        cache_file_identifier: 'cache-thumbnail',
        cache_filename: 'source_thumbnail.jpg'
      )

      expect(cache_service).to have_received(:fetch_stream).with(
        file_identifier: 'cache-thumbnail',
        original_filename: 'source_thumbnail.jpg'
      )
      expect(service).to have_received(:attach_single_file_to_work).with(
        file_path: kind_of(String),
        user: depositor,
        service_file: true,
        source_file_set: source_file_set
      )
      expect(cached_io).to be_closed
    end
  end
end
