# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Catalog range search', type: :routing do
  it 'routes distribution requests to the catalog range action' do
    expect(get: '/catalog/range_limit').to route_to('catalog#range_limit')
  end
end
