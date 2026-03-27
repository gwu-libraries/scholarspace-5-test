# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe '#pdf_viewer_file_id_for_work' do
    let(:presenter) do
      instance_double(
        'Presenter',
        member_ids: %w[source rendering],
        representative_presenter: nil,
        member_presenters: []
      )
    end

    let(:source_original_file) do
      instance_double('OriginalFile', mime_type: 'application/pdf', original_filename: 'work.pdf')
    end

    let(:rendering_original_file) do
      instance_double('OriginalFile', mime_type: 'application/pdf', original_filename: 'work_OCR_RENDERING.pdf')
    end

    let(:source_file_set) { instance_double('FileSet', id: 'source', original_file: source_original_file) }
    let(:rendering_file_set) { instance_double('FileSet', id: 'rendering', original_file: rendering_original_file) }

    before do
      allow(Hyrax).to receive(:query_service).and_return(query_service)
    end

    context 'when an OCR rendering derivative exists' do
      let(:query_service) { instance_double('QueryService') }

      before do
        allow(query_service).to receive(:find_by).with(id: 'source').and_return(source_file_set)
        allow(query_service).to receive(:find_by).with(id: 'rendering').and_return(rendering_file_set)
      end

      it 'prefers OCR rendering PDF for viewer' do
        expect(helper.pdf_viewer_file_id_for_work(presenter)).to eq('rendering')
      end
    end

    context 'when OCR rendering derivative does not exist' do
      let(:query_service) { instance_double('QueryService') }

      before do
        allow(query_service).to receive(:find_by).with(id: 'source').and_return(source_file_set)
        allow(query_service).to receive(:find_by).with(id: 'rendering').and_return(nil)
      end

      it 'falls back to source PDF for viewer' do
        expect(helper.pdf_viewer_file_id_for_work(presenter)).to eq('source')
      end
    end
  end
end
