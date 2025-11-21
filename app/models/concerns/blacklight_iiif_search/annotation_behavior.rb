# frozen_string_literal: true

# customizable behavior for IiifSearchAnnotation
module BlacklightIiifSearch
  module AnnotationBehavior
    ##
    # Create a URL for the annotation
    # @return [String]
    def annotation_id
      "#{controller.solr_document_url(parent_document.id)}/canvas/#{document.id}/annotation/#{index}"
    end

    ##
    # Create a URL for the canvas that the annotation refers to
    # @return [String]
    def canvas_uri_for_annotation
      "#{controller.solr_document_url(parent_document.id)}/canvas/#{document.id}" +
        highlight_coordinates
    end

    ##
    # return a string like "#xywh=100,100,250,20"
    # corresponding to coordinates of query term on image
    # @return [String]
    def region_coordinates
    # In case any of the necessary coordinate components are missing, return empty string for xywh
      unless [
               region_ulx,
               region_uly,
               region_lrx,
               region_lry
             ].all? { |x| x.present? }
        return ""
      end
      # converting ulx/uly/lrx/lry format to xywh format
      x = region_ulx.to_i
      y = region_uly.to_i
      w = region_lrx.to_i - region_ulx.to_i
      h = region_lry.to_i - region_uly.to_i

      "#xywh=#{x},#{y},#{w},#{h}"
    end

    def highlight_coordinates
    # In case any of the necessary coordinate components are missing, return empty string for xywh
      unless [
               highlight_ulx,
               highlight_uly,
               highlight_lrx,
               highlight_lry
             ].all? { |x| x.present? }
        return ""
      end
      # converting ulx/uly/lrx/lry format to xywh format
      x = highlight_ulx.to_i
      y = highlight_uly.to_i
      w = highlight_lrx.to_i - highlight_ulx.to_i
      h = highlight_lry.to_i - highlight_uly.to_i

      "#xywh=#{x},#{y},#{w},#{h}"
    end
  end
end
