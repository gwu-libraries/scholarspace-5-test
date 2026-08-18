# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkShowSerializer do
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
  let(:presenter) do
    double(
      'work_show_presenter',
      id: 'work-id',
      title: ['Work title'],
      description: ['Work description'],
      original_item_members: [original_member],
      service_item_members: [service_member, representative_thumbnail_member],
      thumbnail_id: nil
    )
  end
  let(:roles) { FakeRoles.new(exists_result: true) }
  let(:user) { instance_double(User, admin?: false, roles: roles) }
  let(:view_context) do
    double(
      'view_context',
      can?: false,
      current_user: user
    )
  end

  let(:thumbnail_resolver) { instance_double(ThumbnailResolver, thumbnail_paths_by_member_id: {}) }

  before do
    allow(ThumbnailResolver).to receive(:new).and_return(thumbnail_resolver)
  end

  it 'emits separate original and admin-visible service members for the file panel' do
    props = described_class.new(presenter: presenter, view_context: view_context).as_json

    expect(props[:canViewServiceFiles]).to eq(true)
    expect(props[:originalMembers].pluck(:id)).to eq(['original-file-set'])
    expect(props[:serviceMembers].pluck(:id)).to match_array(['service-file-set', 'representative-thumbnail-file-set'])
    expect(props[:serviceMembers].find { |member| member[:id] == 'service-file-set' }[:sourceFileSetId]).to eq('original-file-set')
  end

  it 'marks representative thumbnails as work-level service members even when source-linked' do
    props = described_class.new(presenter: presenter, view_context: view_context).as_json
    representative_thumbnail = props[:serviceMembers].find { |member| member[:id] == 'representative-thumbnail-file-set' }

    expect(representative_thumbnail[:sourceFileSetId]).to eq('original-file-set')
    expect(representative_thumbnail[:isRepresentativeThumbnail]).to eq(true)
  end

  it 'uses persisted thumbnail resolution for large works' do
    original_members = 81.times.map do |index|
      FakeFilePanelMember.new(
        id: "original-file-set-#{index}",
        title: ["source-#{index}.jpg"],
        mime_type: 'image/jpeg',
        solr_document: { 'service_file_bsi' => false }
      )
    end
    allow(presenter).to receive(:original_item_members).and_return(original_members)

    described_class.new(presenter: presenter, view_context: view_context).as_json

    expect(thumbnail_resolver).to have_received(:thumbnail_paths_by_member_id).with(
      members: original_members,
      service_members: [service_member, representative_thumbnail_member]
    )
  end
end