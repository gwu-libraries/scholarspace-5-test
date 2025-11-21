# frozen_string_literal: true

# corresponds to a IIIF Annotation List
module BlacklightIiifSearch
  class IiifSearchResponse
    include BlacklightIiifSearch::Ignored

    attr_reader :solr_response, :controller, :iiif_config

    ##
    # @param [Blacklight::Solr::Response] solr_response
    # @param [SolrDocument] parent_document
    # @param [CatalogController] controller
    def initialize(solr_response, parent_document, controller)
      @solr_response = solr_response
      @parent_document = parent_document
      @controller = controller
      @iiif_config = controller.iiif_search_config
      @resources = []
      @hits = []
    end

    ##
    # constructs the IIIF::Presentation::AnnotationList
    # @return [IIIF::OrderedHash]
    def annotation_list
      list_id = controller.request.original_url
      anno_list = IIIF::Presentation::AnnotationList.new("@id" => list_id)

      anno_list["@context"] = %w[
        http://iiif.io/api/presentation/2/context.json
        http://iiif.io/api/search/1/context.json
      ]

      anno_list["resources"] = resources.uniq

      # anno_list["hits"] = @hits.uniq

      # anno_list["within"] = within

      # anno_list["prev"] = paged_url(
      #   solr_response.prev_page
      # ) if solr_response.prev_page
      # anno_list["next"] = paged_url(
      #   solr_response.next_page
      # ) if solr_response.next_page

      # anno_list["startIndex"] = 0 unless solr_response.total_pages > 1
      anno_list["startIndex"] = 0 
      anno_list.to_ordered_hash(force: true, include_context: false)
    end

    ##
    # Return an array of IiifSearchAnnotation objects
    # @return [Array]
    def resources
      # logic like return blahblah if solr_response['response']['numFound'] < 1
      @total = solr_response["response"]["numFound"]

      result_hash = {}

      ocr_highlighting_result = solr_response["ocrHighlighting"]

      ocr_highlighting_result.each do |id, hit|
        # rh = { "@type": "search:Hit", annotations: [] }

        document = SolrDocument.find(id)

        # if there are hits
        hit.each_with_index do |h, idx|          
          r = h.last['snippets'].first
          
          hit_score = r["score"]
          hit_pages = r["pages"]
          hit_regions = r["regions"]
          hit_highlights = r["highlights"]
          
          hit_highlights.flatten.each do |hh|

            region = hit_regions[hh["parentRegionIdx"].to_i]
            page = hit_pages[region["pageIdx"].to_i]

            annotation =
              IiifSearchAnnotation.new(
                idx,
                document, # this needs to be the actual solr doc??
                @parent_document,
                page["id"],
                @controller,
                region["ulx"],
                region["uly"],
                region["lrx"],
                region["lry"],
                hh["ulx"],
                hh["uly"],
                hh["lrx"],
                hh["lry"]
              )

            @resources << annotation.as_hash
            # rh[:annotations] << annotation.annotation_id
          end
        end
        # @hits << rh
      end
      @resources
    end

    ##
    # @return [IIIF::Presentation::Layer]
    def within
      within_hash = IIIF::Presentation::Layer.new
      within_hash["ignored"] = ignored

      if solr_response["response"]["numFound"] > 1
        within_hash["first"] = paged_url(1)
        within_hash["last"] = paged_url(solr_response["response"]["numFound"])
      else
        within_hash["total"] = @total
      end
      within_hash
    end

    ##
    # create a URL for the previous/next page of results
    # @return [String]
    def paged_url(page_index)
      controller.solr_document_iiif_search_url(
        clean_params.merge(page: page_index)
      )
    end

    ##
    # remove ignored or irrelevant params from the params hash
    # @return [ActionController::Parameters]
    def clean_params
      remove = ignored.map(&:to_sym)
      controller.iiif_search_params.except(*%i[page solr_document_id] + remove)
    end
  end
end
