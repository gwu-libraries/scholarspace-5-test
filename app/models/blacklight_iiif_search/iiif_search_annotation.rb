# frozen_string_literal: true

# corresponds to IIIF Annotation resource
module BlacklightIiifSearch
  class IiifSearchAnnotation
    include IIIF::Presentation
    include BlacklightIiifSearch::AnnotationBehavior

    attr_reader :index,
                :document,
                :parent_document,
                :page_id,
                :controller,
                :region_ulx,
                :region_uly,
                :region_lrx,
                :region_lry,
                :highlight_ulx,
                :highlight_uly,
                :highlight_lrx,
                :highlight_lry

    def initialize(
      index,
      document,
      parent_document,
      page_id,
      controller,
      region_ulx,
      region_uly,
      region_lrx,
      region_lry,
      highlight_ulx,
      highlight_uly,
      highlight_lrx,
      highlight_lry
    )
      @index = index
      @document = document
      @parent_document = parent_document
      @page_id = page_id
      @controller = controller
      @region_ulx = region_ulx
      @region_uly = region_uly
      @region_lrx = region_lrx
      @region_lry = region_lry
      @highlight_ulx = highlight_ulx
      @highlight_uly = highlight_uly
      @highlight_lrx = highlight_lrx
      @highlight_lry = highlight_lry
    end
    # rubocop:enable Metrics/ParameterLists

    ##
    # @return [IIIF::Presentation::Annotation]
    def as_hash
      annotation = IIIF::Presentation::Annotation.new("@id" => annotation_id.gsub("?locale=en", ""))
      annotation["on"] = canvas_uri_for_annotation.gsub("?locale=en", "")
      annotation
    end
  end
end
