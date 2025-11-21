# return a IIIF Content Search response
module BlacklightIiifSearch
  module Controller
    extend ActiveSupport::Concern

    included do
      before_action :set_search_builder, only: [:iiif_search]
      after_action :set_access_headers, only: %i[iiif_search]
    end

    def iiif_search
      @parent_document =
        Hyrax.query_service.find_by(id: params[:solr_document_id])

      @response =
        Hyrax
          .query_service
          .custom_queries
          .find_by_ocr_text_and_parent_document_id(
          ocr_text: params[:q],
          parent_document_id: @parent_document.id
        )

      iiif_search_response =
        IiifSearchResponse.new(@response, @parent_document, self)

        
      render json: iiif_search_response.annotation_list,
             content_type: "application/json"
    end

    def iiif_search_config
      blacklight_config.iiif_search || {}
    end

    def iiif_search_params
      params.permit(:q, :motivation, :date, :user, :solr_document_id, :page)
    end

    private

    def set_search_builder
      blacklight_config.search_builder_class = IiifSearchBuilder
    end

    # allow apps to load JSON received from a remote server
    def set_access_headers
      response.headers["Access-Control-Allow-Origin"] = "*"
    end
  end
end
