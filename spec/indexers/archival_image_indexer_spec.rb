# # frozen_string_literal: true

# # Generated via
# #  `rails generate hyrax:work_resource ArchivalDocument`
# require 'rails_helper'
# require 'hyrax/specs/shared_specs/indexers'

# RSpec.describe ArchivalDocumentIndexer do
#   describe '#to_solr' do
#     let(:user) { User.create(email: 'test@example.com', password: 'password') }
#     let(:resource) do
#       FactoryBot.valkyrie_create(:archival_document, user: user)
#     end
#     let(:indexer) { described_class.new(resource: resource) }

#     it 'provides indifferent access' do
#       expect(indexer.to_solr).to be_a HashWithIndifferentAccess
#     end

#     it 'provides id, date_uploaded_dtsi, and date_modified_dtsi' do
#       expect(indexer.to_solr).to match a_hash_including(
#         id: resource.id.to_s,
#         date_uploaded_dtsi: resource.created_at,
#         date_modified_dtsi: resource.updated_at,
#         system_create_dtsi: resource.created_at,
#         system_modified_dtsi: resource.updated_at
#       )
#     end
#   end
# end
