require 'rails_helper'

RSpec.describe ThumbnailResolver do
  let(:routes) { instance_double('Routes') }
  let(:query_service) { instance_double('Hyrax::QueryService') }
  let(:custom_queries) { double('CustomQueries') }

  subject(:resolver) do
    described_class.new(
      query_service: query_service,
      custom_queries: custom_queries,
      routes: routes
    )
  end

  describe '#thumbnail_path_for_member' do
    let(:source_member) do
      instance_double(
        'SourceMember',
        id: 'source-1',
        label: 'source.jpg',
        title: ['source.jpg'],
        model: instance_double('SourceModel', related_url: []),
        solr_document: {}
      )
    end

    let(:thumbnail_member) do
      instance_double(
        'ThumbnailMember',
        id: 'thumb-1',
        label: 'source_THUMBNAIL.jpg',
        title: ['source_THUMBNAIL.jpg'],
        model: instance_double('ThumbnailModel', related_url: ['source_file_set_id:source-1', 'derivative_type:thumbnail']),
        solr_document: {}
      )
    end

    it 'returns persisted thumbnail service member path when present' do
      allow(routes).to receive(:download_path).with(id: 'thumb-1', locale: nil).and_return('/downloads/thumb-1')

      path = resolver.thumbnail_path_for_member(member: source_member, service_members: [thumbnail_member])

      expect(path).to eq('/downloads/thumb-1')
    end

    it 'falls back to derivative thumbnail path when no persisted thumbnail member exists' do
      allow(routes).to receive(:download_path).with(id: 'source-1', file: 'thumbnail', locale: nil).and_return('/downloads/source-1?file=thumbnail')

      path = resolver.thumbnail_path_for_member(member: source_member, service_members: [])

      expect(path).to eq('/downloads/source-1?file=thumbnail')
    end
  end

  describe '#persisted_thumbnail_url_for_file_set' do
    let(:source_original) { instance_double('OriginalFile', original_filename: 'source-image.jpg') }
    let(:thumb_original) { instance_double('OriginalFile', original_filename: 'source-image_THUMBNAIL.jpg') }
    let(:source_file_set) { instance_double('SourceFileSet', id: 'source-1', original_file: source_original) }
    let(:thumb_file_set) { instance_double('ThumbFileSet', id: 'thumb-1', service_file: true, title: ['source-image_THUMBNAIL.jpg'], original_file: thumb_original) }
    let(:work) { instance_double('Work', member_ids: %w[source-1 thumb-1]) }

    before do
      allow(query_service).to receive(:find_by).with(id: 'source-1').and_return(source_file_set)
      allow(custom_queries).to receive(:find_parent_work).with(resource: source_file_set).and_return(work)
      allow(query_service).to receive(:find_by).with(id: 'thumb-1').and_return(thumb_file_set)
    end

    it 'returns persisted thumbnail download url when a persisted thumbnail file set exists' do
      allow(routes).to receive(:download_url).with(id: 'thumb-1', host: 'example.test').and_return('https://example.test/downloads/thumb-1')

      url = resolver.persisted_thumbnail_url_for_file_set(file_set_id: 'source-1', host: 'example.test')

      expect(url).to eq('https://example.test/downloads/thumb-1')
    end

    it 'falls back to derivative thumbnail url when no persisted thumbnail file set exists' do
      allow(query_service).to receive(:find_by).with(id: 'thumb-1').and_raise(Valkyrie::Persistence::ObjectNotFoundError)
      allow(query_service).to receive(:find_by_alternate_identifier).with(alternate_identifier: 'thumb-1').and_raise(Valkyrie::Persistence::ObjectNotFoundError)
      allow(routes).to receive(:download_url).with(id: 'source-1', file: 'thumbnail', host: 'example.test').and_return('https://example.test/downloads/source-1?file=thumbnail')

      url = resolver.persisted_thumbnail_url_for_file_set(file_set_id: 'source-1', host: 'example.test')

      expect(url).to eq('https://example.test/downloads/source-1?file=thumbnail')
    end
  end

  describe '#representative_thumbnail_path_for_work' do
    let(:rep_original) { instance_double('OriginalFile', original_filename: 'REPRESENTATIVE_THUMBNAIL.jpg') }
    let(:representative_thumb) { instance_double('RepresentativeThumb', id: 'rep-1', service_file: true, title: ['REPRESENTATIVE_THUMBNAIL.jpg'], original_file: rep_original) }
    let(:work) { instance_double('Work', thumbnail_id: 'rep-1') }

    it 'returns download path when work thumbnail is a persisted representative thumbnail' do
      allow(query_service).to receive(:find_by).with(id: 'rep-1').and_return(representative_thumb)
      allow(routes).to receive(:download_path).with(id: 'rep-1', locale: nil).and_return('/downloads/rep-1')

      path = resolver.representative_thumbnail_path_for_work(work: work)

      expect(path).to eq('/downloads/rep-1')
    end
  end
end
