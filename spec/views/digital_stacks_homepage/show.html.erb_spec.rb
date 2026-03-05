# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'digital_stacks_homepage/show', type: :view do
  it 'exists' do
    visit '/digitalstacks'

    expect(page).to have_content('Digital Stacks Homepage')
  end
end
