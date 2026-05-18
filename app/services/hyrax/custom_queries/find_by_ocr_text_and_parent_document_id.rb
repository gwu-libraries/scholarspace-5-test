# frozen_string_literal: true

# @example
#   model = 'Publication'
#   deduplication_key = 'jhqsdhdwhcolh'
#
#   Hyrax.query_service.custom_queries.find_by_model_and_property_value(model:, property: :deduplication_key, value: 'jhqsdhdwhcolh')
#
# @see https://github.com/samvera/valkyrie/wiki/Queries#custom-queries
module Hyrax
  module CustomQueries
    class FindByOcrTextAndParentDocumentId
      def self.queries
        [:find_by_ocr_text_and_parent_document_id]
      end

      attr_reader :query_service

      delegate :resource_factory, to: :query_service
      delegate :orm_class, to: :resource_factory

      def initialize(query_service:)
        @query_service = query_service

        @connection = Hyrax.index_adapter.connection
      end

      def find_by_ocr_text_and_parent_document_id(
        ocr_text:,
        parent_document_id:,
        rows: 50
      )
        @ocr_text = ocr_text
        @parent_document_id = parent_document_id

        @connection.get('select', params: solr_params(rows: rows))
      end

      # Solr query for for a Publication with a deduplication_key_tesi that matches the provided key
      # @return [Hash]
      def query
        escaped_parent = RSolr.solr_escape(@parent_document_id.to_s)
        "(#{escaped_query}) AND (is_page_of_ssim:\"#{escaped_parent}\" OR id:\"#{escaped_parent}\")"
      end

      def escaped_query
        escaped_text = RSolr.solr_escape(@ocr_text.to_s)
        "ocr_text:#{escaped_text} OR all_text_tsimv:#{escaped_text}"
      end

      def solr_params(rows:)
        {
          q: query,
          fl: 'id,is_page_of_ssim,file_format_tesim',
          rows: rows,
          facet: false,
          hl: true,
          'hl.method': 'unified',
          'hl.ocr.fl': 'ocr_text',
          'hl.snippets': 10,
          'hl.fragsize': 0
        }
      end
    end
  end
end
