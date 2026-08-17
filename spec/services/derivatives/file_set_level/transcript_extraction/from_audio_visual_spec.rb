# frozen_string_literal: true

require 'rails_helper'
require 'stringio'

RSpec.describe Derivatives::FileSetLevel::TranscriptExtraction::FromAudioVisual do
  subject(:service) { described_class.new(work) }

  let(:depositor) { instance_double('User') }
  let(:work) do
    instance_double(
      'Work',
      id: 'work-audio_visual-1',
      depositor: 'depositor@example.edu',
      member_file_sets: member_file_sets
    )
  end
  let(:member_file_sets) { [audio_file_set, video_file_set, image_file_set, service_audio_file_set] }

  def build_file_set(id:, filename:, mime_type:, service_file: false, related_url: [], title: [filename])
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
      related_url: related_url,
      title: title
    )
  end

  let(:audio_file_set) { build_file_set(id: 'audio-1', filename: 'lecture.mp3', mime_type: 'audio/mpeg') }
  let(:video_file_set) { build_file_set(id: 'video-1', filename: 'lecture.mp4', mime_type: 'application/octet-stream') }
  let(:image_file_set) { build_file_set(id: 'image-1', filename: 'page.tif', mime_type: 'image/tiff') }
  let(:service_audio_file_set) { build_file_set(id: 'service-audio-1', filename: 'service.mp3', mime_type: 'audio/mpeg', service_file: true) }

  describe '#source_file_set_ids' do
    it 'returns non-service audio/video sources, including generic mp4 files inferred by filename' do
      expect(service.source_file_set_ids).to contain_exactly('audio-1', 'video-1')
    end
  end

  describe '#generate_to_cache' do
    it 'generates and caches a VTT payload for the requested source file set' do
      allow(User).to receive(:find_by).with(email: 'depositor@example.edu').and_return(depositor)
      allow(service).to receive(:copy_single_audio_visual_to_working_dir).with(audio_file_set).and_return('/tmp/lecture.mp3')
      allow(service).to receive(:transcription_source_path).with('/tmp/lecture.mp3').and_return('/tmp/lecture.wav')
      allow(service).to receive(:generate_vtt) do |transcription_source, output_dir:, title:|
        expect(transcription_source).to eq('/tmp/lecture.wav')
        expect(title).to eq('lecture')
        FileUtils.mkdir_p(output_dir)
        File.join(output_dir, 'lecture_VTT.vtt').tap { |path| File.write(path, 'WEBVTT') }
      end
      allow(DerivativeCacheService.instance).to receive(:store_derivative_from_path)

      payload = service.generate_to_cache(source_file_set_id: 'audio-1')

      expect(DerivativeCacheService.instance).to have_received(:store_derivative_from_path).with(
        file_identifier: 'derivatives:audio_transcript:work:work-audio_visual-1:source:audio-1:lecture_VTT.vtt',
        original_filename: 'lecture_VTT.vtt',
        source_path: kind_of(String),
        derivative_type: 'transcript'
      )
      expect(payload).to eq(
        source_file_set_id: 'audio-1',
        cache_file_identifier: 'derivatives:audio_transcript:work:work-audio_visual-1:source:audio-1:lecture_VTT.vtt',
        cache_filename: 'lecture_VTT.vtt'
      )
    end
  end

  describe '#persist_from_cache' do
    let(:existing_transcript) do
      build_file_set(
        id: 'transcript-1',
        filename: 'lecture_VTT.vtt',
        mime_type: 'text/vtt',
        service_file: true,
        related_url: ['source_file_set_id:audio-1', 'derivative_type:transcript']
      )
    end
    let(:member_file_sets) { [audio_file_set, existing_transcript] }
    let(:cached_io) { StringIO.new('WEBVTT replacement') }

    it 'replaces an existing linked transcript and keeps rendering ids current' do
      allow(User).to receive(:find_by).with(email: 'depositor@example.edu').and_return(depositor)
      allow(DerivativeCacheService.instance).to receive(:fetch_stream).with(
        file_identifier: 'cache-transcript-1',
        original_filename: 'lecture_VTT.vtt'
      ).and_return(cached_io)
      allow(service).to receive(:replace_file_set_file).and_return(existing_transcript)
      allow(service).to receive(:update_work_rendering_ids)
      allow(service).to receive(:attach_single_file_to_work)

      service.persist_from_cache(
        source_file_set_id: 'audio-1',
        cache_file_identifier: 'cache-transcript-1',
        cache_filename: 'lecture_VTT.vtt'
      )

      expect(service).to have_received(:replace_file_set_file).with(
        file_set: existing_transcript,
        file_path: kind_of(String),
        user: depositor
      )
      expect(service).to have_received(:update_work_rendering_ids).with(existing_transcript)
      expect(service).not_to have_received(:attach_single_file_to_work)
    end
  end
end
