# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HyraxHelper, type: :helper do
  describe '#render_ocr_snippets' do
    it 'accepts Blacklight field helper keyword arguments' do
      html = helper.render_ocr_snippets(
        document: instance_double('SolrDocument'),
        field: 'all_text_tsimv',
        config: instance_double('Blacklight::Configuration::Field'),
        value: ['alpha <em>beta</em>'.html_safe]
      )

      expect(html).to include('class="ocr-snippet"')
    end

    it 'renders highlighted OCR snippets' do
      html = helper.render_ocr_snippets(value: ['alpha <em>beta</em>'.html_safe])

      expect(html).to include('class="ocr-snippet"')
      expect(html).to include('alpha <em>beta</em>')
    end

    it 'does not render raw full-text values as snippets' do
      html = helper.render_ocr_snippets(value: ['full text without highlights'])

      expect(html).to eq('')
    end
  end
end