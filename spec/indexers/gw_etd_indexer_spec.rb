# frozen_string_literal: true

require "rails_helper"
require "hyrax/specs/shared_specs/indexers"

RSpec.describe GwEtdIndexer do
  let(:indexer_class) { described_class }
  let(:resource) { GwEtd.new }

  it_behaves_like "a Hyrax::Resource indexer"
end
