# frozen_string_literal: true

require "rails_helper"
require "hyrax/specs/shared_specs/indexers"

RSpec.describe GwJournalIssueIndexer do
  let(:indexer_class) { described_class }
  let(:resource) { GwJournalIssue.new }

  it_behaves_like "a Hyrax::Resource indexer"
end