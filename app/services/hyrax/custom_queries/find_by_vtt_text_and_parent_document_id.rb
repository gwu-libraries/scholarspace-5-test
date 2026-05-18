# frozen_string_literal: true

module Hyrax
  module CustomQueries
    class FindByVttTextAndParentDocumentId
      def self.queries
        [:find_by_vtt_text_and_parent_document_id]
      end

      attr_reader :query_service

      delegate :resource_factory, to: :query_service
      delegate :orm_class, to: :resource_factory

      def initialize(query_service:)
        @query_service = query_service
        @connection = Hyrax.index_adapter.connection
      end

      def find_by_vtt_text_and_parent_document_id(vtt_text:, parent_document_id:, rows: 50)
        @vtt_text = vtt_text
        @parent_document_id = parent_document_id

        @connection.get('select', params: solr_params(rows: rows))
      end

      private

      def solr_params(rows:)
        escaped_text = RSolr.solr_escape(@vtt_text.to_s)
        escaped_parent = RSolr.solr_escape(@parent_document_id.to_s)

        {
          q: "id:\"#{escaped_parent}\" AND vtt_text_tesim:#{escaped_text}",
          fl: 'id,vtt_text_tesim',
          rows: rows,
          facet: false,
          hl: true,
          'hl.fl': 'vtt_text_tesim',
          'hl.snippets': 10,
          'hl.fragsize': 180
        }
      end
    end
  end
end
