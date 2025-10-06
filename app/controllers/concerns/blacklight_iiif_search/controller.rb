# return a IIIF Content Search response
module BlacklightIiifSearch
  module Controller
    extend ActiveSupport::Concern

    included do
      before_action :set_search_builder, only: [:iiif_search]
      after_action :set_access_headers, only: %i[iiif_search iiif_suggest]
    end

    def iiif_search
      # override to fix query service instead of "fetch"
      connection = Hyrax.index_adapter.connection

      @parent_document =
        Hyrax.query_service.find_by(id: params[:solr_document_id])

      iiif_search =
        IiifSearch.new(iiif_search_params, iiif_search_config, @parent_document)

      # change below to adjust 'search_results' method and use a Hyrax.index_service or somerthing?
      # @response, _document_list = search_results(iiif_search.solr_params)

      @response = connection.get("select", iiif_search.solr_params)

      @document_list = @response["response"]["docs"]

      iiif_search_response =
        IiifSearchResponse.new(@response, @parent_document, self)

        # ALEX LOOK HERE
      # works up until here, then an issue with .each on solr_document['highlight']
      render json: iiif_search_response.annotation_list,
             content_type: "application/json"
    end

    def iiif_suggest
      suggest_search = IiifSuggestSearch.new(params, repository, self)
      render json: suggest_search.response, content_type: "application/json"
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
