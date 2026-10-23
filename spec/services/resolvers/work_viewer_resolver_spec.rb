# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Resolvers::WorkViewerResolver do
  def member(id, mime: 'application/pdf', filename: "#{id}.pdf", service: false, source_id: nil, presentation: false)
    tags = []
    tags << "source_file_set_id:#{source_id}" if source_id
    tags << 'derivative_type:presentation_version' if presentation
    double(id: id, mime_type: mime, label: filename, service_file: service, related_url: tags)
  end

  let(:source) { member('source') }
  let(:presentation) { member('presentation', service: true, source_id: source.id, presentation: true) }
  let(:reading_pdf) { member('reading', filename: 'reading_mode_pdf.pdf', service: true) }
  let(:members) { [source, presentation] }
  let(:presenter) { double(id: 'work', member_presenters: members) }
  subject(:resolver) { described_class.new(presenter: presenter) }

  describe '#pdf_file_id' do
    it 'selects the linked, tagged presentation PDF' do
      expect(resolver.pdf_file_id).to eq(presentation.id)
    end

    it 'prefers the reading-mode PDF over individual presentation PDFs' do
      members << reading_pdf
      expect(resolver.pdf_file_id).to eq(reading_pdf.id)
    end

    it 'does not substitute a source PDF or an untagged filename match' do
      members.replace([source, member('untagged', filename: 'source_presentation_version.pdf',
                                                 service: true, source_id: source.id)])
      expect(resolver.pdf_file_id).to be_nil
      expect(resolver.preferred_download_member(source.id)).to be_nil
    end

    it 'skips unlinked derivatives and continues to the next source with a presentation' do
      other = member('other')
      linked = member('other-presentation', service: true, source_id: other.id, presentation: true)
      members.replace([source, other, member('unlinked', service: true, presentation: true), linked])
      expect(resolver.pdf_file_id).to eq(linked.id)
    end
  end

  describe '#preferred_download_member' do
    it 'returns a presentation derivative for a source and service files directly' do
      expect(resolver.preferred_download_member(source.id)).to eq(presentation)
      expect(resolver.preferred_download_member(presentation.id)).to eq(presentation)
    end

    it 'resolves a member outside the presenter and caches the lookup' do
      external = member('external', service: true)
      query = double
      allow(Hyrax).to receive(:query_service).and_return(query)
      expect(query).to receive(:find_by).with(id: external.id).once.and_return(external)
      2.times { expect(resolver.preferred_download_member(external.id)).to eq(external) }
    end

    it 'propagates repository lookup failures' do
      query = double
      allow(Hyrax).to receive(:query_service).and_return(query)
      allow(query).to receive(:find_by).with(id: 'missing').and_raise(KeyError, 'missing file')
      expect { resolver.preferred_download_member('missing') }.to raise_error(KeyError, 'missing file')
    end
  end

  describe '#images?' do
    let(:source) { member('image', mime: 'image/tiff', filename: 'image.tif') }
    let(:presentation) do
      member('image-presentation', mime: 'image/jpeg', filename: 'image.jpg',
                                   service: true, source_id: source.id, presentation: true)
    end

    it 'requires a source image with a linked presentation derivative' do
      expect(resolver.images?).to be true
      expect(resolver.preferred_download_member(source.id)).to eq(presentation)
    end

    it 'accepts the legacy filename fallback for non-PDF presentations' do
      fallback = member('fallback', mime: 'image/jpeg', filename: 'IMAGE_PRESENTATION_VERSION.jpg',
                                   service: true, source_id: source.id)
      members.replace([source, fallback])
      expect(resolver.images?).to be true
      expect(resolver.preferred_download_member(source.id)).to eq(fallback)
    end

    it 'prefers metadata-tagged presentations over filename matches and thumbnails' do
      fallback = member('fallback', mime: 'image/jpeg', filename: 'image_presentation_version.jpg',
                                   service: true, source_id: source.id)
      thumbnail = member('thumbnail', mime: 'image/jpeg', service: true, source_id: source.id)
      members.unshift(thumbnail, fallback)
      expect(resolver.preferred_download_member(source.id)).to eq(presentation)
    end

    it 'does not enable images for sources without presentations' do
      members.replace([source])
      expect(resolver.images?).to be false
      expect(resolver.preferred_download_member(source.id)).to be_nil
    end

    it 'does not treat a service image alone as a source image' do
      members.replace([presentation])
      expect(resolver.images?).to be false
    end

    it 'preserves PDF precedence when a source has mixed derivative types' do
      untagged_pdf = member('pdf', service: true, source_id: source.id)
      members << untagged_pdf
      expect(resolver.images?).to be false
      expect(resolver.preferred_download_member(source.id)).to be_nil
    end
  end

  describe '#hocr_file_id' do
    it 'selects HOCR linked to the requested PDF' do
      hocr = member('hocr', mime: 'text/vnd.hocr+html', service: true, source_id: presentation.id)
      members << hocr
      expect(resolver.hocr_file_id(presentation.id)).to eq(hocr.id)
      expect(resolver.hocr_file_id(source.id)).to be_nil
    end

    it 'prefers the work-wide reading-mode HOCR over metadata-linked HOCR' do
      linked = member('linked', mime: 'text/vnd.hocr+html', service: true, source_id: reading_pdf.id)
      reading_hocr = member('reading-hocr', mime: 'text/vnd.hocr+html',
                                           filename: 'reading_mode_pdf_HOCR.hocr', service: true)
      members.concat([reading_pdf, linked, reading_hocr])
      expect(resolver.hocr_file_id(reading_pdf.id)).to eq(reading_hocr.id)
    end

    it 'falls back to metadata-linked HOCR when reading-mode HOCR is absent' do
      linked = member('linked', mime: 'text/vnd.hocr+html', service: true, source_id: reading_pdf.id)
      members.concat([reading_pdf, linked])
      expect(resolver.hocr_file_id(reading_pdf.id)).to eq(linked.id)
    end

    it 'returns no HOCR for an absent PDF identifier' do
      expect(resolver.hocr_file_id(nil)).to be_nil
      expect(resolver.hocr_file_id('')).to be_nil
    end
  end

  describe 'member representations' do
    it 'supports presenters with member IDs and caches repository lookups' do
      presenter = double(member_ids: [source.id, presentation.id])
      query = double
      allow(Hyrax).to receive(:query_service).and_return(query)
      expect(query).to receive(:find_by).with(id: source.id).once.and_return(source)
      expect(query).to receive(:find_by).with(id: presentation.id).once.and_return(presentation)
      resolver = described_class.new(presenter: presenter)

      2.times { expect(resolver.pdf_file_id).to eq(presentation.id) }
    end

    it 'uses Solr service flags and linkage when no model is exposed' do
      solr_member = double(id: 'solr-pdf', mime_type: 'application/pdf', title: ['presentation.pdf'],
                           solr_document: { 'service_file_bsi' => 'true',
                                            'related_url_tesim' => ['source_file_set_id:source',
                                                                   'derivative_type:presentation_version'] })
      members.replace([source, solr_member])
      expect(resolver.pdf_file_id).to eq(solr_member.id)
    end

    it 'uses original-file metadata for models without presenter metadata methods' do
      original_file = double(original_filename: 'reading_mode_pdf.pdf', mime_type: 'application/pdf')
      model = double(service_file: true, original_file: original_file)
      wrapped = double(id: 'wrapped', model: model)
      members.replace([wrapped])
      expect(resolver.pdf_file_id).to eq(wrapped.id)
    end

    it 'returns no selections for a presenter without members' do
      resolver = described_class.new(presenter: double)
      expect(resolver.pdf_file_id).to be_nil
      expect(resolver.images?).to be false
    end

    it 'keeps caches isolated between works' do
      other = described_class.new(presenter: double(member_presenters: [source]))
      expect(resolver.pdf_file_id).to eq(presentation.id)
      expect(other.pdf_file_id).to be_nil
    end
  end
end
