# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CatalogHelper, type: :helper do
  describe '#render_catalog_description' do
    it 'truncates values after twenty words before passing them to the link formatter' do
      words = (1..22).map { |word| "word#{word}" }
      allow(helper).to receive(:iconify_auto_link) { |options| options[:value].join(' ') }

      result = helper.render_catalog_description(value: [words.join(' ')])

      expect(result).to eq("#{words.first(20).join(' ')}...")
    end

    it 'does not add an ellipsis to values with twenty words or fewer' do
      allow(helper).to receive(:iconify_auto_link) { |options| options[:value].join(' ') }

      result = helper.render_catalog_description(value: ['<em>one two three</em>'])

      expect(result).to eq('one two three')
    end
  end
end
