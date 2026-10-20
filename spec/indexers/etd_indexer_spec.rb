# frozen_string_literal: true

require "rails_helper"
require "hyrax/specs/shared_specs/indexers"

RSpec.describe ETDIndexer do
  let(:indexer_class) { described_class }
  let(:resource) { ETD.new }

  it_behaves_like "a Hyrax::Resource indexer"
end
