require 'rails_helper'

RSpec.describe Hyrax::ScholarspaceIiifManifestBuilder do
  describe Hyrax::ScholarspaceIiifManifestBuilder::FileSetPresenterWrapper do
    let(:pdf_model) do
      instance_double(
        'PdfModel',
        original_file: instance_double('OriginalFile', original_filename: nil),
        label: 'Sample Document.pdf',
        title: ['Sample Document.pdf']
      )
    end
    let(:hocr_model) do
      instance_double(
        'HocrModel',
        original_file: instance_double('OriginalFile', original_filename: nil),
        label: 'custom-ocr-name.hocr',
        title: ['custom-ocr-name.hocr'],
        related_url: ['source_file_set_id:pdf-1']
      )
    end
    let(:pdf_presenter) do
      instance_double('PdfPresenter', model: pdf_model, id: 'pdf-1', label: 'Sample Document.pdf', title: ['Sample Document.pdf'], file_set?: true)
    end
    let(:hocr_presenter) do
      instance_double('HocrPresenter', model: hocr_model, id: 'hocr-1', label: 'Sample Document_HOCR.hocr', title: ['Sample Document_HOCR.hocr'], file_set?: true)
    end
    let(:work_presenter) { instance_double('WorkPresenter') }
    let(:pdf_wrapper) { described_class.new(pdf_presenter, work_presenter) }

    before do
      allow(work_presenter).to receive(:member_presenters).and_return([pdf_wrapper, hocr_presenter])
    end

    it 'matches hocr siblings by source metadata linkage when original_filename is blank' do
      match = pdf_wrapper.send(:matching_hocr_sibling_presenter)
      expect(match).to eq(hocr_presenter)
    end

    context 'when matching transcript siblings for multiple AV files' do
      let(:video_model) do
        instance_double(
          'VideoModel',
          original_file: instance_double('OriginalFile', original_filename: nil),
          label: 'lecture.mp4',
          title: ['lecture.mp4']
        )
      end
      let(:video_presenter) do
        instance_double(
          'VideoPresenter',
          model: video_model,
          id: 'video-1',
          label: 'lecture.mp4',
          title: ['lecture.mp4'],
          file_set?: true,
          video?: true,
          audio?: false,
          mime_type: 'video/mp4'
        )
      end
      let(:video_wrapper) { described_class.new(video_presenter, work_presenter) }
      let(:matching_vtt_presenter) do
        instance_double(
          'TranscriptPresenter',
          model: instance_double(
            'TranscriptModel',
            original_file: instance_double('OriginalFile', original_filename: nil),
            label: 'custom-caption.vtt',
            title: ['custom-caption.vtt'],
            related_url: ['source_file_set_id:video-1']
          ),
          id: 'vtt-1',
          label: 'custom-caption.vtt',
          title: ['custom-caption.vtt'],
          file_set?: true,
          audio?: false,
          video?: false,
          mime_type: 'text/vtt'
        )
      end
      let(:other_vtt_presenter) do
        instance_double(
          'TranscriptPresenter',
          model: instance_double(
            'TranscriptModel',
            original_file: instance_double('OriginalFile', original_filename: nil),
            label: 'another-caption.vtt',
            title: ['another-caption.vtt'],
            related_url: ['source_file_set_id:video-2']
          ),
          id: 'vtt-2',
          label: 'another-caption.vtt',
          title: ['another-caption.vtt'],
          file_set?: true,
          audio?: false,
          video?: false,
          mime_type: 'text/vtt'
        )
      end
      let(:other_video_presenter) do
        instance_double(
          'VideoPresenter',
          model: instance_double('VideoModel', original_file: instance_double('OriginalFile', original_filename: nil), label: 'interview.mp4', title: ['interview.mp4']),
          id: 'video-2',
          label: 'interview.mp4',
          title: ['interview.mp4'],
          file_set?: true,
          video?: true,
          audio?: false,
          mime_type: 'video/mp4'
        )
      end

      before do
        allow(work_presenter).to receive(:member_presenters).and_return([
          video_wrapper,
          described_class.new(other_video_presenter, work_presenter),
          matching_vtt_presenter,
          other_vtt_presenter
        ])
      end

      it 'matches only transcript files for the current AV source metadata id' do
        matches = video_wrapper.send(:transcript_sibling_presenters)
        expect(matches).to contain_exactly(matching_vtt_presenter)
      end
    end

    context 'when there is exactly one AV file and one transcript' do
      let(:audio_model) do
        instance_double(
          'AudioModel',
          original_file: instance_double('OriginalFile', original_filename: nil),
          label: 'session.wav',
          title: ['session.wav']
        )
      end
      let(:audio_presenter) do
        instance_double(
          'AudioPresenter',
          model: audio_model,
          id: 'audio-1',
          label: 'session.wav',
          title: ['session.wav'],
          file_set?: true,
          video?: false,
          audio?: true,
          mime_type: 'audio/wav'
        )
      end
      let(:audio_wrapper) { described_class.new(audio_presenter, work_presenter) }
      let(:transcript_presenter) do
        instance_double(
          'TranscriptPresenter',
          model: instance_double('TranscriptModel', original_file: instance_double('OriginalFile', original_filename: nil), label: 'custom-transcript.vtt', title: ['custom-transcript.vtt']),
          id: 'vtt-1',
          label: 'custom-transcript.vtt',
          title: ['custom-transcript.vtt'],
          file_set?: true,
          audio?: false,
          video?: false,
          mime_type: 'text/vtt'
        )
      end

      before do
        allow(work_presenter).to receive(:member_presenters).and_return([audio_wrapper, transcript_presenter])
      end

      it 'returns no transcript when source metadata linkage is missing' do
        matches = audio_wrapper.send(:transcript_sibling_presenters)
        expect(matches).to eq([])
      end
    end

    context 'when transcript linkage exists but the service flag is missing' do
      let(:presenter) { Hyrax::ScholarspaceWorkShowPresenter.allocate }
      let(:audio_presenter) do
        instance_double(
          'AudioPresenter',
          id: 'audio-1',
          label: 'session.wav',
          title: ['session.wav'],
          file_set?: true,
          audio?: true,
          video?: false,
          mime_type: 'audio/wav',
          solr_document: {}
        )
      end
      let(:transcript_presenter) do
        instance_double(
          'TranscriptPresenter',
          id: 'vtt-1',
          label: 'session_VTT.vtt',
          title: ['session_VTT.vtt'],
          file_set?: true,
          audio?: false,
          video?: false,
          mime_type: 'text/vtt',
          model: instance_double(
            'TranscriptModel',
            original_file: instance_double('OriginalFile', original_filename: nil),
            label: 'session_VTT.vtt',
            title: ['session_VTT.vtt'],
            related_url: ['source_file_set_id:audio-1']
          ),
          solr_document: {}
        )
      end

      before do
        allow(presenter).to receive(:member_presenters).and_return([audio_presenter, transcript_presenter])
        allow(presenter).to receive(:list_of_item_ids_to_display).and_return([audio_presenter.id, transcript_presenter.id])
        presenter.define_singleton_method(:representative_id) { nil }
      end

      it 'includes the transcript for the source AV file' do
        expect(presenter.transcript_files).to contain_exactly(
          hash_including(
            id: 'vtt-1',
            label: 'session_VTT.vtt',
            url: '/downloads/vtt-1.vtt',
            format: 'text/vtt',
            canvasId: 0
          )
        )
      end
    end

    context 'when non-AV members are mixed with multiple AV members' do
      let(:presenter) { Hyrax::ScholarspaceWorkShowPresenter.allocate }
      let(:audio_presenter) do
        instance_double(
          'AudioPresenter',
          id: 'audio-1',
          label: 'session.wav',
          title: ['session.wav'],
          file_set?: true,
          audio?: true,
          video?: false,
          mime_type: 'audio/wav',
          solr_document: {}
        )
      end
      let(:video_presenter) do
        instance_double(
          'VideoPresenter',
          id: 'video-2',
          label: 'interview.mp4',
          title: ['interview.mp4'],
          file_set?: true,
          audio?: false,
          video?: true,
          mime_type: 'video/mp4',
          solr_document: {}
        )
      end
      let(:pdf_presenter) do
        instance_double(
          'PdfPresenter',
          id: 'pdf-1',
          label: 'document.pdf',
          title: ['document.pdf'],
          file_set?: true,
          audio?: false,
          video?: false,
          mime_type: 'application/pdf',
          solr_document: {}
        )
      end
      let(:audio_transcript_presenter) do
        instance_double(
          'AudioTranscriptPresenter',
          id: 'vtt-1',
          label: 'session_VTT.vtt',
          title: ['session_VTT.vtt'],
          file_set?: true,
          audio?: false,
          video?: false,
          mime_type: 'text/vtt',
          model: instance_double(
            'AudioTranscriptModel',
            original_file: instance_double('OriginalFile', original_filename: nil),
            label: 'session_VTT.vtt',
            title: ['session_VTT.vtt'],
            related_url: ['source_file_set_id:audio-1']
          ),
          solr_document: {}
        )
      end
      let(:video_transcript_presenter) do
        instance_double(
          'VideoTranscriptPresenter',
          id: 'vtt-2',
          label: 'interview_VTT.vtt',
          title: ['interview_VTT.vtt'],
          file_set?: true,
          audio?: false,
          video?: false,
          mime_type: 'text/vtt',
          model: instance_double(
            'VideoTranscriptModel',
            original_file: instance_double('OriginalFile', original_filename: nil),
            label: 'interview_VTT.vtt',
            title: ['interview_VTT.vtt'],
            related_url: ['source_file_set_id:video-2']
          ),
          solr_document: {}
        )
      end

      before do
        # Include a non-AV member between AV members to ensure transcript canvas
        # ids are based on AV order, not raw member position.
        allow(presenter).to receive(:member_presenters).and_return([
          audio_presenter,
          pdf_presenter,
          video_presenter,
          audio_transcript_presenter,
          video_transcript_presenter
        ])
        allow(presenter).to receive(:list_of_item_ids_to_display).and_return([
          audio_presenter.id,
          pdf_presenter.id,
          video_presenter.id,
          audio_transcript_presenter.id,
          video_transcript_presenter.id
        ])
        presenter.define_singleton_method(:representative_id) { nil }
      end

      it 'assigns transcript canvas ids based on item order' do
        expect(presenter.transcript_files).to contain_exactly(
          hash_including(id: 'vtt-1', canvasId: 0),
          hash_including(id: 'vtt-2', canvasId: 1)
        )
      end
    end

    context 'when representative AV is not first in item order' do
      let(:presenter) { Hyrax::ScholarspaceWorkShowPresenter.allocate }
      let(:first_av_presenter) do
        instance_double(
          'FirstAvPresenter',
          id: 'av-1',
          label: 'first.mp4',
          title: ['first.mp4'],
          file_set?: true,
          audio?: false,
          video?: true,
          mime_type: 'video/mp4',
          solr_document: {}
        )
      end
      let(:second_av_presenter) do
        instance_double(
          'SecondAvPresenter',
          id: 'av-2',
          label: 'second.mp4',
          title: ['second.mp4'],
          file_set?: true,
          audio?: false,
          video?: true,
          mime_type: 'video/mp4',
          solr_document: {}
        )
      end
      let(:first_vtt_presenter) do
        instance_double(
          'FirstVttPresenter',
          id: 'vtt-1',
          label: 'first_VTT.vtt',
          title: ['first_VTT.vtt'],
          file_set?: true,
          audio?: false,
          video?: false,
          mime_type: 'text/vtt',
          model: instance_double(
            'FirstVttModel',
            original_file: instance_double('OriginalFile', original_filename: nil),
            label: 'first_VTT.vtt',
            title: ['first_VTT.vtt'],
            related_url: ['source_file_set_id:av-1']
          ),
          solr_document: {}
        )
      end
      let(:second_vtt_presenter) do
        instance_double(
          'SecondVttPresenter',
          id: 'vtt-2',
          label: 'second_VTT.vtt',
          title: ['second_VTT.vtt'],
          file_set?: true,
          audio?: false,
          video?: false,
          mime_type: 'text/vtt',
          model: instance_double(
            'SecondVttModel',
            original_file: instance_double('OriginalFile', original_filename: nil),
            label: 'second_VTT.vtt',
            title: ['second_VTT.vtt'],
            related_url: ['source_file_set_id:av-2']
          ),
          solr_document: {}
        )
      end

      before do
        allow(presenter).to receive(:member_presenters).and_return([
          first_av_presenter,
          second_av_presenter,
          first_vtt_presenter,
          second_vtt_presenter
        ])
        allow(presenter).to receive(:list_of_item_ids_to_display).and_return([
          first_av_presenter.id,
          second_av_presenter.id,
          first_vtt_presenter.id,
          second_vtt_presenter.id
        ])

        # Representative should not affect transcript canvas assignment.
        presenter.define_singleton_method(:representative_id) { 'av-2' }
      end

      it 'keeps transcript canvas ids aligned with item order' do
        expect(presenter.transcript_files).to contain_exactly(
          hash_including(id: 'vtt-1', canvasId: 0),
          hash_including(id: 'vtt-2', canvasId: 1)
        )
      end
    end
  end

  describe Hyrax::ScholarspaceIiifManifestBuilder::WorkPresenterWrapper do
    let(:presenter_a) { instance_double('PresenterA', id: 'file-a') }
    let(:presenter_b) { instance_double('PresenterB', id: 'file-b') }
    let(:source_presenter) do
      instance_double('WorkPresenter', member_presenters: [presenter_a, presenter_b], representative_id: 'file-b')
    end
    let(:wrapper) { described_class.new(source_presenter) }

    it 'orders member presenters with representative first' do
      ordered_ids = wrapper.member_presenters.map { |presenter| presenter.id.to_s }
      expect(ordered_ids).to eq(%w[file-b file-a])
    end
  end
end