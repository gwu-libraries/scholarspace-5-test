# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hyrax::FileSetPresenter do
  let(:ability) { instance_double('Ability') }

  describe '#alt_text_for_view' do
    it 'uses the solr document alt_text_for_view when available' do
      solr_document = double('SolrDocument', alt_text_for_view: 'Alt text from document')
      presenter = described_class.new(solr_document, ability)

      expect(presenter.alt_text_for_view).to eq('Alt text from document')
    end

    it 'falls back to indexed alt text when the solr document does not define alt_text_for_view' do
      solr_document = {
        'alt_text_tesim' => ['Indexed alt text'],
        'title_tesim' => ['File title']
      }
      presenter = described_class.new(solr_document, ability)

      expect(presenter.alt_text_for_view).to eq('Indexed alt text')
    end

    it 'falls back to the presenter title when no indexed alt text is present' do
      solr_document = {
        'alt_text_tesim' => [],
        'title_tesim' => ['File title']
      }
      presenter = described_class.new(solr_document, ability)

      expect(presenter.alt_text_for_view).to eq('File title')
    end
  end
end