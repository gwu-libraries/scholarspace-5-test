# frozen_string_literal: true

require 'rails_helper'
require 'stringio'

RSpec.describe Derivatives::FileSetLevel::PresentationVersion do
  let(:image_presentation) { described_class::FromImage.new(work) }
  let(:audio_visual_presentation) { described_class::FromAudioVisual.new(work) }
  let(:pdf_presentation) { described_class::FromPdf.new(work) }

  let(:depositor) { instance_double('User') }
  let(:work) do
    instance_double(
      'Work',
      id: 'work-1',
      depositor: 'depositor@example.edu',
      member_file_sets: member_file_sets
    )
  end
  let(:member_file_sets) { [image_file_set, service_image_file_set, pdf_file_set, audio_file_set, video_file_set] }

  def build_file_set(id:, filename:, mime_type:, service_file: false, related_url: [])
    original_file = instance_double(
      'OriginalFile',
      mime_type: mime_type,
      original_filename: filename,
      file_identifier: "fid-#{id}"
    )

    instance_double(
      'FileSet',
      id: id,
      original_file: original_file,
      service_file: service_file,
      related_url: related_url
    )
  end

  let(:image_file_set) { build_file_set(id: 'image-1', filename: 'page.tif', mime_type: 'image/tiff') }
  let(:service_image_file_set) { build_file_set(id: 'service-image-1', filename: 'service-page.tif', mime_type: 'image/tiff', service_file: true) }
  let(:pdf_file_set) { build_file_set(id: 'pdf-1', filename: 'source.pdf', mime_type: 'application/pdf') }
  let(:audio_file_set) { build_file_set(id: 'audio-1', filename: 'lecture.mp3', mime_type: 'audio/mpeg') }
  let(:video_file_set) { build_file_set(id: 'video-1', filename: 'lecture.mp4', mime_type: 'application/octet-stream') }

  describe 'source file set id helpers' do
    it 'returns supported non-service sources by derivative type' do
      expect(image_presentation.source_file_set_ids).to eq(['image-1'])
      expect(pdf_presentation.source_file_set_ids).to eq(['pdf-1'])
      expect(audio_visual_presentation.source_file_set_ids).to contain_exactly('audio-1', 'video-1')
    end
  end

  describe 'FromImage#generate_to_cache' do
    it 'builds and caches a presentation image payload using a web-friendly extension' do
      allow(User).to receive(:find_by).with(email: 'depositor@example.edu').and_return(depositor)
      allow(image_presentation).to receive(:copy_source_to_path).with(image_file_set, dir: kind_of(String)).and_return('/tmp/source-page.tif')
      allow(image_presentation).to receive(:build_presentation) do |source_path:, output_path:|
        expect(source_path).to eq('/tmp/source-page.tif')
        File.write(output_path, 'presentation image')
      end
      allow(DerivativeCacheService.instance).to receive(:store_derivative_from_path)

      payload = image_presentation.generate_to_cache(source_file_set_id: 'image-1')

      expect(DerivativeCacheService.instance).to have_received(:store_derivative_from_path).with(
        file_identifier: 'derivatives:presentation_version:work:work-1:source:image-1:page_presentation_version.jpg',
        original_filename: 'page_presentation_version.jpg',
        source_path: kind_of(String),
        derivative_type: 'presentation_version'
      )
      expect(payload).to eq(
        source_file_set_id: 'image-1',
        cache_file_identifier: 'derivatives:presentation_version:work:work-1:source:image-1:page_presentation_version.jpg',
        cache_filename: 'page_presentation_version.jpg'
      )
    end
  end

  describe 'FromImage#persist_from_cache' do
    let(:existing_presentation) do
      build_file_set(
        id: 'presentation-1',
        filename: 'page_presentation_version.jpg',
        mime_type: 'image/jpeg',
        service_file: true,
        related_url: ['source_file_set_id:image-1', 'derivative_type:presentation_version']
      )
    end
    let(:member_file_sets) { [image_file_set, existing_presentation] }
    let(:cached_io) { StringIO.new('replacement presentation image') }

    it 'replaces an existing linked presentation file instead of attaching a duplicate' do
      allow(User).to receive(:find_by).with(email: 'depositor@example.edu').and_return(depositor)
      allow(DerivativeCacheService.instance).to receive(:fetch_stream).with(
        file_identifier: 'cache-image-1',
        original_filename: 'page_presentation_version.jpg'
      ).and_return(cached_io)
      allow(image_presentation).to receive(:replace_file_set_file)
      allow(image_presentation).to receive(:attach_single_file_to_work)
      allow(image_presentation).to receive(:reindex_work_and_file_set)

      image_presentation.persist_from_cache(
        source_file_set_id: 'image-1',
        cache_file_identifier: 'cache-image-1',
        cache_filename: 'page_presentation_version.jpg'
      )

      expect(image_presentation).to have_received(:replace_file_set_file).with(
        file_set: existing_presentation,
        file_path: kind_of(String),
        user: depositor
      )
      expect(image_presentation).not_to have_received(:attach_single_file_to_work)
      expect(image_presentation).not_to have_received(:reindex_work_and_file_set)
    end

    it 'reindexes the work and presentation file set after replacing an existing linked presentation file' do
      allow(User).to receive(:find_by).with(email: 'depositor@example.edu').and_return(depositor)
      allow(DerivativeCacheService.instance).to receive(:fetch_stream).with(
        file_identifier: 'cache-image-1',
        original_filename: 'page_presentation_version.jpg'
      ).and_return(cached_io)
      allow(image_presentation).to receive(:replace_file_set_file).and_return(existing_presentation)
      allow(image_presentation).to receive(:reindex_work_and_file_set)

      image_presentation.persist_from_cache(
        source_file_set_id: 'image-1',
        cache_file_identifier: 'cache-image-1',
        cache_filename: 'page_presentation_version.jpg'
      )

      expect(image_presentation).to have_received(:reindex_work_and_file_set).with(existing_presentation)
    end

    it 'reindexes the work and presentation file set after attaching a new presentation file' do
      new_presentation = build_file_set(
        id: 'presentation-2',
        filename: 'page_v2_presentation_version.jpg',
        mime_type: 'image/jpeg',
        service_file: true,
        related_url: ['source_file_set_id:image-1', 'derivative_type:presentation_version']
      )

      allow(User).to receive(:find_by).with(email: 'depositor@example.edu').and_return(depositor)
      allow(DerivativeCacheService.instance).to receive(:fetch_stream).with(
        file_identifier: 'cache-image-1',
        original_filename: 'page_v2_presentation_version.jpg'
      ).and_return(cached_io)
      allow(image_presentation).to receive(:attach_single_file_to_work).and_return(new_presentation)
      allow(image_presentation).to receive(:reindex_work_and_file_set)

      image_presentation.persist_from_cache(
        source_file_set_id: 'image-1',
        cache_file_identifier: 'cache-image-1',
        cache_filename: 'page_v2_presentation_version.jpg'
      )

      expect(image_presentation).to have_received(:attach_single_file_to_work).with(
        file_path: kind_of(String),
        user: depositor,
        service_file: true,
        source_file_set: image_file_set,
        derivative_type_override: 'presentation_version'
      )
      expect(image_presentation).to have_received(:reindex_work_and_file_set).with(new_presentation)
    end
  end

  describe 'FromPdf#persist_from_cache' do
    let(:existing_text_presentation) do
      build_file_set(
        id: 'presentation-pdf-1',
        filename: 'source_presentation_version.pdf',
        mime_type: 'application/pdf',
        service_file: true,
        related_url: ['source_file_set_id:pdf-1', 'derivative_type:presentation_version']
      )
    end
    let(:member_file_sets) { [pdf_file_set, existing_text_presentation] }
    let(:cached_io) { StringIO.new('compressed presentation pdf') }

    it 'keeps an existing text-bearing PDF presentation instead of replacing it' do
      allow(User).to receive(:find_by).with(email: 'depositor@example.edu').and_return(depositor)
      allow(DerivativeCacheService.instance).to receive(:fetch_stream).with(
        file_identifier: 'cache-pdf-1',
        original_filename: 'source_presentation_version.pdf'
      ).and_return(cached_io)
      allow(pdf_presentation).to receive(:presentation_pdf_contains_embedded_text?).with(existing_text_presentation).and_return(true)
      allow(pdf_presentation).to receive(:replace_file_set_file)
      allow(pdf_presentation).to receive(:attach_single_file_to_work)
      allow(pdf_presentation).to receive(:reindex_work_and_file_set)

      pdf_presentation.persist_from_cache(
        source_file_set_id: 'pdf-1',
        cache_file_identifier: 'cache-pdf-1',
        cache_filename: 'source_presentation_version.pdf'
      )

      expect(pdf_presentation).not_to have_received(:replace_file_set_file)
      expect(pdf_presentation).not_to have_received(:attach_single_file_to_work)
      expect(pdf_presentation).to have_received(:reindex_work_and_file_set).with(existing_text_presentation)
    end
  end
end
