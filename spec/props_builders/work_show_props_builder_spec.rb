# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkShowPropsBuilder do
  FakeFilePanelMember = Struct.new(:id, :title, :mime_type, :solr_document, keyword_init: true) do
    def label
      title.to_a.first.to_s
    end
  end

  FakeRoles = Struct.new(:exists_result, keyword_init: true) do
    def where(name:)
      self
    end

    def exists?
      exists_result
    end
  end

  let(:original_member) do
    FakeFilePanelMember.new(
      id: 'original-file-set',
      title: ['source.pdf'],
      mime_type: 'application/pdf',
      solr_document: { 'service_file_bsi' => false }
    )
  end
  let(:service_member) do
    FakeFilePanelMember.new(
      id: 'service-file-set',
      title: ['source_presentation.pdf'],
      mime_type: 'application/pdf',
      solr_document: {
        'service_file_bsi' => true,
        'related_url_tesim' => ['source_file_set_id:original-file-set']
      }
    )
  end
  let(:representative_thumbnail_member) do
    FakeFilePanelMember.new(
      id: 'representative-thumbnail-file-set',
      title: ['REPRESENTATIVE_THUMBNAIL.jpg'],
      mime_type: 'image/jpeg',
      solr_document: {
        'service_file_bsi' => true,
        'related_url_tesim' => [
          'source_file_set_id:original-file-set',
          'representative_thumbnail_for_work:work-id'
        ]
      }
    )
  end
  let(:reading_mode_member) do
    FakeFilePanelMember.new(
      id: 'reading-mode-file-set',
      title: ['reading_mode_pdf.pdf'],
      mime_type: 'application/pdf',
      solr_document: { 'service_file_bsi' => true }
    )
  end
  let(:presenter) do
    double(
      'work_show_presenter',
      id: 'work-id',
      title: ['Work title'],
      description: ['Work description'],
      original_item_members: [original_member],
      service_item_members: [service_member, representative_thumbnail_member],
      representative_presenter: nil,
      thumbnail_id: nil
    )
  end
  let(:roles) { FakeRoles.new(exists_result: true) }
  let(:user) { instance_double(User, admin?: false, roles: roles) }
  let(:view_context) do
    double(
      'view_context',
      can?: false,
      current_user: user,
      pdf_viewer_file_id_for_work: nil,
      preferred_download_url_for_member: nil,
      hocr_download_url_for_work: nil
    )
  end

  let(:thumbnail_resolver) { instance_double(Resolvers::ThumbnailResolver, thumbnail_paths_by_member_id: {}) }

  before do
    allow(Resolvers::ThumbnailResolver).to receive(:new).and_return(thumbnail_resolver)
  end

  it 'emits separate original and admin-visible service members for the file panel' do
    props = described_class.new(presenter: presenter, view_context: view_context).build

    expect(props[:canViewServiceFiles]).to eq(true)
    expect(props[:originalMembers].pluck(:id)).to eq(['original-file-set'])
    expect(props[:serviceMembers].pluck(:id)).to match_array(['service-file-set', 'representative-thumbnail-file-set'])
    expect(props[:serviceMembers].find { |member| member[:id] == 'service-file-set' }[:sourceFileSetId]).to eq('original-file-set')
  end

  it 'marks representative thumbnails as work-level service members even when source-linked' do
    props = described_class.new(presenter: presenter, view_context: view_context).build
    representative_thumbnail = props[:serviceMembers].find { |member| member[:id] == 'representative-thumbnail-file-set' }

    expect(representative_thumbnail[:sourceFileSetId]).to eq('original-file-set')
    expect(representative_thumbnail[:isRepresentativeThumbnail]).to eq(true)
  end

  context 'with a reading-mode PDF' do
    before do
      allow(presenter).to receive(:service_item_members).and_return(
        [service_member, representative_thumbnail_member, reading_mode_member]
      )
      allow(view_context).to receive(:preferred_download_url_for_member)
        .with(presenter, reading_mode_member.id).and_return('/downloads/reading-mode-file-set')
      allow(view_context).to receive(:hocr_download_url_for_work)
        .with(presenter, pdf_file_id: reading_mode_member.id).and_return('/downloads/reading-mode-hocr')
    end

    it 'provides reading-mode URLs to administrators' do
      props = described_class.new(presenter: presenter, view_context: view_context).build

      expect(props[:readingModePdf]).to eq(
        fileUrl: '/downloads/reading-mode-file-set',
        hocrUrl: '/downloads/reading-mode-hocr'
      )
      expect(props[:canViewServiceFiles]).to eq(true)
      expect(props[:serviceMembers].pluck(:id)).to include(reading_mode_member.id)
    end

    context 'for a non-admin user' do
      let(:roles) { FakeRoles.new(exists_result: false) }

      it 'provides reading-mode URLs without exposing the service-file list' do
        props = described_class.new(presenter: presenter, view_context: view_context).build

        expect(props[:readingModePdf]).to eq(
          fileUrl: '/downloads/reading-mode-file-set',
          hocrUrl: '/downloads/reading-mode-hocr'
        )
        expect(props[:canViewServiceFiles]).to eq(false)
        expect(props[:serviceMembers]).to eq([])
      end
    end

    context 'for an anonymous user' do
      let(:user) { nil }

      it 'provides reading-mode URLs without exposing the service-file list' do
        props = described_class.new(presenter: presenter, view_context: view_context).build

        expect(props[:readingModePdf]).to eq(
          fileUrl: '/downloads/reading-mode-file-set',
          hocrUrl: '/downloads/reading-mode-hocr'
        )
        expect(props[:canViewServiceFiles]).to eq(false)
        expect(props[:serviceMembers]).to eq([])
      end
    end

    it 'supports reading mode when no hOCR sidecar is available' do
      allow(view_context).to receive(:hocr_download_url_for_work)
        .with(presenter, pdf_file_id: reading_mode_member.id).and_return(nil)

      props = described_class.new(presenter: presenter, view_context: view_context).build

      expect(props[:readingModePdf]).to eq(fileUrl: '/downloads/reading-mode-file-set', hocrUrl: nil)
    end
  end

  it 'does not offer reading mode for works with only ordinary presentation PDFs' do
    props = described_class.new(presenter: presenter, view_context: view_context).build

    expect(props[:readingModePdf]).to be_nil
  end

  it 'uses fallback thumbnail URLs for large works' do
    original_members = 81.times.map do |index|
      FakeFilePanelMember.new(
        id: "original-file-set-#{index}",
        title: ["source-#{index}.jpg"],
        mime_type: 'image/jpeg',
        solr_document: { 'service_file_bsi' => false }
      )
    end
    allow(presenter).to receive(:original_item_members).and_return(original_members)

    props = described_class.new(presenter: presenter, view_context: view_context).build

    expect(props[:originalMembers].size).to eq(original_members.size)
    props[:originalMembers].each do |member|
      expect(member[:thumbnailUrl]).to eq(
        Hyrax::Engine.routes.url_helpers.download_path(id: member[:id], file: 'thumbnail', locale: nil)
      )
    end
    expect(thumbnail_resolver).not_to have_received(:thumbnail_paths_by_member_id).with(
      members: original_members,
      service_members: [service_member, representative_thumbnail_member]
    )
  end

  it 'includes ETD metadata in the work show payload' do
    allow(presenter).to receive(:solr_document).and_return(
      {
        'gw_affiliation_tesim' => ['GW Libraries'],
        'degree_tesim' => ['M.P.S.'],
        'advisor_tesim' => ['Advisor Name'],
        'committee_member_tesim' => ['Committee Member'],
        'doi_tesim' => ['10.1234/example']
      }
    )

    metadata = described_class.new(presenter: presenter, view_context: view_context).build[:metadata]

    expect(metadata).to include(
      { name: 'gw_affiliation_tesim', label: 'Gw affiliation', values: ['GW Libraries'] },
      { name: 'degree_tesim', label: 'Degree', values: ['M.P.S.'] },
      { name: 'advisor_tesim', label: 'Advisor', values: ['Advisor Name'] },
      { name: 'committee_member_tesim', label: 'Committee member', values: ['Committee Member'] },
      { name: 'doi_tesim', label: 'Doi', values: ['10.1234/example'] }
    )
  end
end