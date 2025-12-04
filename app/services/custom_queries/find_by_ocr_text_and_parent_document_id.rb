# frozen_string_literal: true

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

    def find_by_ocr_text_and_parent_document_id(ocr_text:, parent_document_id:)
      @ocr_text = ocr_text
      @parent_document_id = parent_document_id

      # ALEX - Does this need to take rows/pages params
      @connection.get('select', params: { q: query, fl: '*', rows: 50 })
    end

    # Solr query for for a Publication with a deduplication_key_tesi that matches the provided key
    # @return [Hash]
    def query
      "ocr_text:#{@ocr_text} AND has_model_ssim:DerivedPage AND (is_page_of_ssim:#{@parent_document_id} OR id:#{@parent_document_id})"
    end
  end
end
