Rails.application.config.to_prepare do
  module BlacklightIiifSearch
    module IiifSearchResponseOcrHighlightingDecorator
      def resources
        ocr_highlighting = solr_response['ocrHighlighting']
        return super unless ocr_highlighting.present?

        @total = 0
        solr_response.documents.each do |document|
          doc_id = document[:id].to_s
          doc_ocr = ocr_highlighting[doc_id] || ocr_highlighting[doc_id.to_sym]
          snippet_matches = extract_ocr_matches(doc_ocr)

          hit = { '@type': 'search:Hit', 'annotations': [] }
          if snippet_matches.empty?
            @total += 1
            annotation = IiifSearchAnnotation.new(document,
                                                  solr_response.params['q'],
                                                  0, nil, controller,
                                                  @parent_document)
            @resources << annotation.as_hash
            hit[:annotations] << annotation.annotation_id
          else
            snippet_matches.each_with_index do |match, hl_index|
              @total += 1
              annotation = IiifSearchAnnotation.new(document,
                                                    solr_response.params['q'],
                                                    hl_index, match[:text], controller,
                                                    @parent_document)
              xywh = xywh_from_region(match[:region])
              annotation.define_singleton_method(:coordinates) { xywh ? "#xywh=#{xywh}" : '' }
              @resources << annotation.as_hash
              hit[:annotations] << annotation.annotation_id
            end
          end

          @hits << hit
        end

        @resources
      end

      private

      def extract_ocr_matches(doc_ocr)
        return [] unless doc_ocr.respond_to?(:each_value)

        doc_ocr.each_value.flat_map do |field_payload|
          next [] unless field_payload.respond_to?(:[])

          Array(field_payload['snippets'] || field_payload[:snippets]).filter_map do |snippet|
            next unless snippet.is_a?(Hash)

            text = snippet['text'] || snippet[:text]
            next unless text

            regions = Array(snippet['regions'] || snippet[:regions])

            if regions.empty?
              { text: text, region: nil }
            else
              regions.filter_map { |region| region.is_a?(Hash) ? { text: text, region: region } : nil }
            end
          end
        end
      end

      def xywh_from_region(region)
        return nil unless region

        ulx = numeric_coordinate(region, 'ulx')
        uly = numeric_coordinate(region, 'uly')
        lrx = numeric_coordinate(region, 'lrx')
        lry = numeric_coordinate(region, 'lry')
        return nil unless [ulx, uly, lrx, lry].all?

        width = (lrx - ulx).round
        height = (lry - uly).round
        return nil if width <= 0 || height <= 0

        "#{ulx.round},#{uly.round},#{width},#{height}"
      end

      def numeric_coordinate(region, key)
        value = region[key] || region[key.to_sym]
        return nil if value.nil?

        Float(value)
      rescue ArgumentError, TypeError
        nil
      end
    end
  end

  BlacklightIiifSearch::IiifSearchResponse.prepend BlacklightIiifSearch::IiifSearchResponseOcrHighlightingDecorator
end