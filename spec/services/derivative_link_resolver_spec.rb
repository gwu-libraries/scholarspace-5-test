# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DerivativeLinkResolver do
  describe 'linkage by source_file_set_id' do
    let(:audio_visual_member) do
      instance_double(
        'AudioVisualMember',
        id: 'audio_visual-1',
        file_set?: true,
        mime_type: 'video/mp4',
        label: 'lecture.mp4',
        model: instance_double('AudioVisualModel', related_url: [], original_file: instance_double('OriginalFile', original_filename: 'lecture.mp4', mime_type: 'video/mp4'))
      )
    end

    let(:transcript_member) do
      instance_double(
        'TranscriptMember',
        id: 'vtt-1',
        file_set?: true,
        mime_type: 'text/vtt',
        label: 'lecture.vtt',
        model: instance_double('TranscriptModel', related_url: ['source_file_set_id:audio_visual-1'], original_file: instance_double('OriginalFile', original_filename: nil, mime_type: 'text/vtt'))
      )
    end

    let(:hocr_member_filename_only) do
      instance_double(
        'HocrFilenameOnly',
        id: 'hocr-filename',
        file_set?: true,
        mime_type: '',
        label: 'ocr-output.hocr',
        model: instance_double('HocrFilenameOnlyModel', related_url: ['source_file_set_id:pdf-1'], original_file: instance_double('OriginalFile', original_filename: nil, mime_type: nil))
      )
    end

    let(:hocr_member_mime_tagged) do
      instance_double(
        'HocrMimeTagged',
        id: 'hocr-mime',
        file_set?: true,
        mime_type: 'text/vnd.hocr+html',
        label: 'ocr-output.txt',
        model: instance_double('HocrMimeTaggedModel', related_url: ['source_file_set_id:pdf-1'], original_file: instance_double('OriginalFile', original_filename: nil, mime_type: 'text/vnd.hocr+html'))
      )
    end

    subject(:resolver) { described_class.new(members: [audio_visual_member, transcript_member, hocr_member_filename_only, hocr_member_mime_tagged]) }

    it 'returns transcript members for a given source id' do
      expect(resolver.transcript_members_for('audio_visual-1')).to contain_exactly(transcript_member)
    end

    it 'prefers mime-tagged hocr members when multiple siblings share a source id' do
      expect(resolver.hocr_member_for('pdf-1')).to eq(hocr_member_mime_tagged)
    end

    it 'does not classify hocr by filename alone' do
      expect(resolver.hocr_file_set?(hocr_member_filename_only)).to be(false)
    end

    it 'extracts source ids from related_url metadata' do
      expect(resolver.source_file_set_id_for(transcript_member)).to eq('audio_visual-1')
    end

    it 'skips derivative members that are missing source linkage metadata' do
      unlinked_transcript = instance_double(
        'UnlinkedTranscript',
        id: 'vtt-2',
        file_set?: true,
        mime_type: 'text/vtt',
        label: 'missing-link.vtt',
        model: instance_double('UnlinkedTranscriptModel', related_url: [], original_file: instance_double('OriginalFile', original_filename: nil, mime_type: 'text/vtt'))
      )

      resolver = described_class.new(members: [unlinked_transcript])

      expect(resolver.transcripts_by_source_id).to eq({})
    end

    it 'classifies transcripts by .vtt extension when mime metadata is missing' do
      filename_only_transcript = instance_double(
        'FilenameOnlyTranscript',
        id: 'vtt-filename-only',
        file_set?: true,
        mime_type: '',
        label: 'lecture_VTT.vtt',
        model: instance_double(
          'FilenameOnlyTranscriptModel',
          related_url: ['source_file_set_id:audio_visual-1'],
          original_file: instance_double('OriginalFile', original_filename: nil, mime_type: nil)
        )
      )

      resolver = described_class.new(members: [audio_visual_member, filename_only_transcript])

      expect(resolver.transcript_members_for('audio_visual-1')).to contain_exactly(filename_only_transcript)
    end

    it 'handles members with nil solr_document when reading related urls' do
      member = instance_double(
        'MemberWithNilSolrDocument',
        model: instance_double('NilSolrModel', related_url: []),
        solr_document: nil
      )

      expect(described_class.related_url_values_for(member)).to eq([])
    end
  end
end
