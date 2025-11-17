module Hyrax
  module SolrDocument
    module Metadata

      included do
        attribute :doi, Solr::Array, "doi_tesim"
        attribute :gw_affiliation, Solr::Array, "gw_affiliation_tesim"
        attribute :bulkrax_identifier, Solr::Array, "bulkrax_identifier_tesim"
      end
    end
  end
end
