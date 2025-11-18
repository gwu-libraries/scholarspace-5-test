# frozen_string_literal: true

require "rails_helper"
require "hyrax/specs/shared_specs/hydra_works"

RSpec.describe GwEtd do
  subject(:work) { described_class.new }

  it_behaves_like "a Hyrax::Work"
end
