# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Derivatives::WorkLevel::RepresentativeThumbnail::FromSourceFileSet do
  subject(:service) { described_class.new(work) }

  let(:work) do
    instance_double(
      'Work',
      id: 'work-1',
      depositor: 'depositor@example.edu',
      member_file_sets: member_file_sets,
      original_member_file_sets: [source_file_set],
      thumbnail_id: nil
    )
  end

  let(:member_file_sets) { [] }
  let(:source_original_file) do
    instance_double('OriginalFile', mime_type: 'image/jpeg', original_filename: 'source-image.jpg')
  end
  let(:source_file_set) { instance_double('FileSet', id: 'source-1', original_file: source_original_file) }
  let(:derivative_thumbnail) { instance_double('FileSet', id: 'thumb-1') }

  describe '#build_representative_thumbnail' do
    let(:depositor) { instance_double('User') }
    let(:representative_thumbnail) { instance_double('FileSet', id: 'rep-1') }

    before do
      service.instance_variable_set(:@working_dir, '/tmp/thumb-service')
      allow(service).to receive(:depositor).and_return(depositor)
      allow(service).to receive(:copy_source_to_working_dir)
      allow(service).to receive(:attach_single_file_to_work)
    end

    it 'creates a copied representative thumbnail with fixed filename' do
      allow(service).to receive(:representative_thumbnail_file_set_by_metadata).and_return(nil)
      allow(service).to receive(:copy_source_to_working_dir).with(derivative_thumbnail).and_return('/tmp/thumb-service/source-thumb.jpg')
      allow(FileUtils).to receive(:cp)
      allow(service).to receive(:attach_single_file_to_work).and_return(representative_thumbnail)
      allow(service).to receive(:tag_as_representative_thumbnail).and_return(representative_thumbnail)

      result = service.send(
        :build_representative_thumbnail,
        derivative_candidates: [{ source_file_set: source_file_set, derivative_thumbnail: derivative_thumbnail }]
      )

      expect(FileUtils).to have_received(:cp).with(
        '/tmp/thumb-service/source-thumb.jpg',
        '/tmp/thumb-service/REPRESENTATIVE_THUMBNAIL.jpg'
      )
      expect(service).to have_received(:attach_single_file_to_work).with(
        file_path: '/tmp/thumb-service/REPRESENTATIVE_THUMBNAIL.jpg',
        user: depositor,
        service_file: true,
        source_file_set: source_file_set
      )
      expect(result).to eq(representative_thumbnail)
    end

    it 'reuses existing representative thumbnail when present' do
      existing = instance_double('FileSet', id: 'rep-existing')
      allow(service).to receive(:representative_thumbnail_file_set_by_metadata).and_return(existing)

      result = service.send(
        :build_representative_thumbnail,
        derivative_candidates: [{ source_file_set: source_file_set, derivative_thumbnail: derivative_thumbnail }]
      )

      expect(service).not_to have_received(:copy_source_to_working_dir)
      expect(service).not_to have_received(:attach_single_file_to_work)
      expect(result).to eq(existing)
    end
  end

  describe '#best_representative_candidate' do
    def build_source_file_set(id:, filename:, mime_type:)
      original_file = instance_double('OriginalFile', mime_type: mime_type, original_filename: filename)
      instance_double(
        'FileSet',
        id: id,
        original_file: original_file,
        image?: mime_type.start_with?('image/'),
        pdf?: mime_type == 'application/pdf',
        audio?: mime_type.start_with?('audio/'),
        video?: mime_type.start_with?('video/')
      )
    end

    it 'prefers image candidates over pdf and audio_visual candidates' do
      image_source = build_source_file_set(id: 'img-1', filename: 'z-image.tif', mime_type: 'image/tiff')
      pdf_source = build_source_file_set(id: 'pdf-1', filename: 'a-document.pdf', mime_type: 'application/pdf')
      audio_visual_source = build_source_file_set(id: 'audio_visual-1', filename: 'a-audio.mp3', mime_type: 'audio/mpeg')

      winner = service.send(
        :best_representative_candidate,
        [
          { source_file_set: pdf_source, derivative_thumbnail: instance_double('FileSet', id: 'thumb-pdf') },
          { source_file_set: audio_visual_source, derivative_thumbnail: instance_double('FileSet', id: 'thumb-audio_visual') },
          { source_file_set: image_source, derivative_thumbnail: instance_double('FileSet', id: 'thumb-img') }
        ]
      )

      expect(winner.fetch(:source_file_set).id).to eq(image_source.id)
    end

    it 'chooses alphabetically first image when multiple images exist' do
      z_image = build_source_file_set(id: 'img-z', filename: 'z-page.tif', mime_type: 'image/tiff')
      a_image = build_source_file_set(id: 'img-a', filename: 'a-page.tif', mime_type: 'image/tiff')

      winner = service.send(
        :best_representative_candidate,
        [
          { source_file_set: z_image, derivative_thumbnail: instance_double('FileSet', id: 'thumb-z') },
          { source_file_set: a_image, derivative_thumbnail: instance_double('FileSet', id: 'thumb-a') }
        ]
      )

      expect(winner.fetch(:source_file_set).id).to eq(a_image.id)
    end

    it 'chooses alphabetically first pdf when no images exist' do
      z_pdf = build_source_file_set(id: 'pdf-z', filename: 'z-document.pdf', mime_type: 'application/pdf')
      a_pdf = build_source_file_set(id: 'pdf-a', filename: 'a-document.pdf', mime_type: 'application/pdf')
      audio_visual_source = build_source_file_set(id: 'audio_visual-1', filename: 'a-audio.mp3', mime_type: 'audio/mpeg')

      winner = service.send(
        :best_representative_candidate,
        [
          { source_file_set: z_pdf, derivative_thumbnail: instance_double('FileSet', id: 'thumb-zpdf') },
          { source_file_set: audio_visual_source, derivative_thumbnail: instance_double('FileSet', id: 'thumb-audio_visual') },
          { source_file_set: a_pdf, derivative_thumbnail: instance_double('FileSet', id: 'thumb-apdf') }
        ]
      )

      expect(winner.fetch(:source_file_set).id).to eq(a_pdf.id)
    end

    it 'chooses alphabetically first audio_visual when only audio_visual candidates exist' do
      z_audio_visual = build_source_file_set(id: 'audio_visual-z', filename: 'z-video.mp4', mime_type: 'video/mp4')
      a_audio_visual = build_source_file_set(id: 'audio_visual-a', filename: 'a-video.mp4', mime_type: 'video/mp4')

      winner = service.send(
        :best_representative_candidate,
        [
          { source_file_set: z_audio_visual, derivative_thumbnail: instance_double('FileSet', id: 'thumb-z-audio_visual') },
          { source_file_set: a_audio_visual, derivative_thumbnail: instance_double('FileSet', id: 'thumb-a-audio_visual') }
        ]
      )

      expect(winner.fetch(:source_file_set).id).to eq(a_audio_visual.id)
    end
  end

  describe '#update_file_set_file' do
    let(:depositor) { instance_double('User') }
    let(:existing_thumbnail) { instance_double('FileSet', id: 'thumb-1') }
    let(:refreshed_thumbnail) { instance_double('FileSet', id: 'thumb-1') }

    it 'uploads replacement content to the existing thumbnail file set' do
      Tempfile.create(['replacement-thumbnail', '.jpg']) do |file|
        file.write('new thumbnail content')
        file.rewind

        allow(service).to receive(:depositor).and_return(depositor)
        allow(Hyrax::ValkyrieUpload).to receive(:file)
        allow(Hyrax.query_service).to receive(:find_by).with(id: 'thumb-1').and_return(refreshed_thumbnail)
        allow(service).to receive(:save_and_index).with(refreshed_thumbnail).and_return(refreshed_thumbnail)

        result = service.send(:update_file_set_file, existing_thumbnail, file.path)

        expect(Hyrax::ValkyrieUpload).to have_received(:file).with(
          filename: File.basename(file.path),
          file_set: existing_thumbnail,
          io: kind_of(File),
          user: depositor,
          skip_derivatives: true
        )
        expect(service).to have_received(:save_and_index).with(refreshed_thumbnail)
        expect(result).to eq(refreshed_thumbnail)
      end
    end
  end

  describe '#set_work_thumbnail' do
    let(:reloaded_work) { instance_double('Work') }
    let(:saved_work) { instance_double('Work') }

    it 'sets the work thumbnail to the representative thumbnail file set' do
      allow(service).to receive(:with_work_lock).and_yield
      allow(service).to receive(:reload_work).and_return(reloaded_work)
      allow(reloaded_work).to receive(:thumbnail_id=)
      allow(service).to receive(:save_and_index).with(reloaded_work).and_return(saved_work)

      result = service.send(:set_work_thumbnail, representative_thumbnail_id: 'rep-1')

      expect(reloaded_work).to have_received(:thumbnail_id=).with('rep-1')
      expect(service).to have_received(:save_and_index).with(reloaded_work)
      expect(result).to eq(saved_work)
    end
  end

  describe '#representative_thumbnail_file_set_by_metadata' do
    let(:representative_file_set) { instance_double('FileSet') }
    let(:other_file_set) { instance_double('FileSet') }
    let(:member_file_sets) { [other_file_set, representative_file_set] }

    it 'finds the service member tagged as the work representative thumbnail' do
      allow(service).to receive(:tags_for_file_set).with(other_file_set).and_return([])
      allow(service).to receive(:tags_for_file_set).with(representative_file_set).and_return([
                                                                                              'representative_thumbnail_for_work:work-1'
                                                                                            ])

      result = service.send(:representative_thumbnail_file_set_by_metadata)

      expect(result).to eq(representative_file_set)
    end
  end
end
