# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IiifBuilders::ManifestBuilder do
  def member(id, mime:, filename:, source_id: nil, presentation: false, fields: {})
    tags = []
    tags << "source_file_set_id:#{source_id}" if source_id
    tags << 'derivative_type:presentation_version' if presentation
    double(id: id, mime_type: mime, label: filename, service_file: source_id.present?,
           related_url: tags, solr_document: fields)
  end

  let(:image) { member('image', mime: 'image/tiff', filename: 'page.tif', fields: { 'width_is' => 800 }) }
  let(:image_presentation) do
    member('image-presentation', mime: 'image/jpeg', filename: 'page.jpg',
                                 source_id: image.id, presentation: true, fields: { 'height_is' => 1000 })
  end
  let(:video) { member('video', mime: 'video/quicktime', filename: 'lecture.mov') }
  let(:video_presentation) do
    member('video-presentation', mime: 'video/mp4', filename: 'lecture.mp4',
                                 source_id: video.id, presentation: true, fields: { 'duration_dtsim' => [120_000] })
  end
  let(:transcript) { member('transcript', mime: 'text/vtt', filename: 'lecture.vtt', source_id: video.id) }
  let(:members) { [image, image_presentation, video, video_presentation, transcript] }
  let(:presenter) do
    double(id: 'work', title: ['Example work'], hostname: 'example.org',
           manifest_url: 'https://example.org/manifest?locale=en', member_presenters: members)
  end

  before do
    allow(Hyrax.config).to receive(:iiif_info_url_builder).and_return(
      ->(id, host) { "https://#{host}/images/#{id}" }
    )
    allow(Hyrax.config).to receive(:iiif_image_size_default).and_return(1200)
    allow(Rails.application.routes.url_helpers).to receive(:solr_document_iiif_search_url)
      .with(solr_document_id: 'work', host: 'example.org').and_return('https://example.org/search/work')
    allow(Hyrax::Engine.routes.url_helpers).to receive(:download_url) do |options|
      "https://#{options.fetch(:host)}/downloads/#{options.fetch(:id)}" \
        "?#{options[:format] ? "format=#{options[:format]}" : "disposition=#{options[:disposition]}"}"
    end
  end

  describe 'viewer selection' do
    it 'defaults missing and unrecognized viewers to Clover' do
      expected = IiifBuilders::Clover.new.manifest_for(presenter: presenter)
      [nil, '', 'clover', 'unknown', 'universal_viewer'].each do |viewer|
        expect(described_class.manifest_for(presenter: presenter, viewer: viewer)).to eq(expected)
      end
    end

    it 'selects Ramp for string and symbol viewer values' do
      expected = IiifBuilders::Ramp.new.manifest_for(presenter: presenter)
      ['ramp', :ramp].each do |viewer|
        expect(described_class.manifest_for(presenter: presenter, viewer: viewer)).to eq(expected)
      end
    end

    it 'preserves both class and instance hash and JSON entry points' do
      [described_class, described_class.new].each do |builder|
        [nil, 'clover', 'ramp'].each do |viewer|
          manifest = builder.manifest_for(presenter: presenter, viewer: viewer)
          json = builder.manifest_json_for(presenter: presenter, viewer: viewer)
          expect(JSON.parse(json)).to eq(manifest)
        end
      end
    end
  end

  describe IiifBuilders::Clover do
    subject(:manifest) { described_class.new.manifest_for(presenter: presenter) }

    it 'builds only image canvases with linked presentation metadata and source image services' do
      expect(manifest['items']).to eq([
                                        {
                                          'id' => '/canvas/image',
                                          'type' => 'Canvas',
                                          'label' => { 'none' => ['page.tif'] },
                                          'height' => 1000,
                                          'width' => 800,
                                          'items' => [
                                            {
                                              'id' => '/canvas/image/page',
                                              'type' => 'AnnotationPage',
                                              'items' => [
                                                {
                                                  'id' => '/canvas/image/page/annotation',
                                                  'type' => 'Annotation',
                                                  'motivation' => 'painting',
                                                  'body' => {
                                                    'id' => 'https://example.org/images/image/full/1200,/0/default.jpg',
                                                    'type' => 'Image',
                                                    'format' => 'image/jpeg',
                                                    'height' => 1000,
                                                    'width' => 800,
                                                    'service' => [
                                                      { 'id' => 'https://example.org/images/image', 'type' => 'ImageService2', 'profile' => 'level2' }
                                                    ]
                                                  },
                                                  'target' => '/canvas/image'
                                                }
                                              ]
                                            }
                                          ]
                                        }
                                      ])
    end

    it 'includes the shared envelope, thumbnail, and Clover search service' do
      expect(manifest).to include(
        '@context' => 'http://iiif.io/api/presentation/3/context.json',
        'id' => 'https://example.org/manifest?viewer=clover',
        'type' => 'Manifest',
        'label' => { 'none' => ['Example work'] },
        'thumbnail' => [{ 'id' => 'https://example.org/images/image-presentation/full/!300,300/0/default.jpg',
                          'type' => 'Image' }],
        'service' => [
          { 'id' => 'https://example.org/search/work', 'type' => 'SearchService1', 'profile' => 'http://iiif.io/api/search/1/search' }
        ]
      )
    end

    it 'uses default image dimensions when no dimensions are available' do
      allow(image).to receive(:solr_document).and_return({})
      allow(image_presentation).to receive(:solr_document).and_return({})
      expect(manifest['items'].first).to include('width' => 1200, 'height' => 1600)
    end

    it 'omits sources without linked presentation derivatives' do
      members.delete(image_presentation)
      expect(manifest['items']).to eq([])
      expect(manifest).not_to have_key('thumbnail')
    end
  end

  describe IiifBuilders::Ramp do
    subject(:manifest) { described_class.new.manifest_for(presenter: presenter) }

    it 'builds only audiovisual canvases with inline presentation media and normalized durations' do
      expect(manifest['id']).to eq('https://example.org/manifest?viewer=ramp')
      expect(manifest).not_to have_key('service')
      expect(manifest['items'].size).to eq(1)
      canvas = manifest['items'].first
      expect(canvas).to include(
        'id' => '/canvas/video', 'type' => 'Canvas', 'label' => { 'none' => ['lecture.mov'] },
        'width' => 640, 'height' => 360, 'duration' => 120.0
      )
      expect(canvas['items']).to eq([
                                      {
                                        'id' => '/canvas/video/page',
                                        'type' => 'AnnotationPage',
                                        'items' => [
                                          {
                                            'id' => '/canvas/video/page/annotation',
                                            'type' => 'Annotation',
                                            'motivation' => 'painting',
                                            'body' => {
                                              'id' => 'https://example.org/downloads/video-presentation?disposition=inline',
                                              'type' => 'Video',
                                              'format' => 'video/mp4',
                                              'label' => { 'none' => ['lecture.mp4'] }
                                            },
                                            'target' => '/canvas/video'
                                          }
                                        ]
                                      }
                                    ])
    end

    it 'includes linked VTT transcripts as supplementing annotations' do
      expect(manifest['items'].first['annotations']).to eq([
                                                             {
                                                               'id' => '/canvas/video/supplementing',
                                                               'type' => 'AnnotationPage',
                                                               'items' => [
                                                                 {
                                                                   'id' => '/canvas/video/supplementing/transcript',
                                                                   'type' => 'Annotation',
                                                                   'motivation' => 'supplementing',
                                                                   'body' => {
                                                                     'id' => 'https://example.org/downloads/transcript?format=vtt',
                                                                     'type' => 'Text',
                                                                     'format' => 'text/vtt',
                                                                     'label' => { 'none' => ['lecture.vtt'] }
                                                                   },
                                                                   'target' => '/canvas/video'
                                                                 }
                                                               ]
                                                             }
                                                           ])
    end

    it 'does not request the Clover search service' do
      expect(Rails.application.routes.url_helpers).not_to receive(:solr_document_iiif_search_url)
      manifest
    end

    it 'uses the fallback duration and an empty annotations list when metadata is absent' do
      allow(video_presentation).to receive(:solr_document).and_return({})
      members.delete(transcript)
      expect(manifest['items'].first).to include('duration' => 1, 'annotations' => [])
    end

    it 'identifies audio even when the MIME type must be inferred from the filename' do
      allow(video).to receive_messages(mime_type: 'application/octet-stream', label: 'recording.wav')
      allow(video_presentation).to receive_messages(mime_type: 'application/octet-stream', label: 'recording.mp3')
      body = manifest['items'].first['items'].first['items'].first['body']
      expect(body).to include('type' => 'Sound', 'format' => 'audio/mpeg')
    end

    it 'omits sources without linked presentation derivatives' do
      members.delete(video_presentation)
      expect(manifest['items']).to eq([])
    end
  end
end
