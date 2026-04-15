Rails.application.config.to_prepare do
  module BlacklightIiifSearch
    module IiifSearchAnnotationManifestCanvasDecorator
      def annotation_id
        "#{iiif_manifest_canvas_base}/annotation/#{hl_index}"
      end

      def canvas_uri_for_annotation
        "#{iiif_manifest_canvas_base}#{coordinates}"
      end

      private

      def iiif_manifest_canvas_base
        return @iiif_manifest_canvas_base if defined?(@iiif_manifest_canvas_base)

        parent_id = parent_document[:id]
        model_name = Array(parent_document[:has_model_ssim] || parent_document['has_model_ssim']).first
        route_key = model_name&.safe_constantize&.model_name&.route_key || model_name.to_s.underscore.pluralize
        route_key = route_key.sub(/\Ahyrax_/, '')
        canvas_id = instance_variable_get(:@iiif_canvas_id_override).presence || document[:id]
        base = controller.request.base_url

        @iiif_manifest_canvas_base = "#{base}/concern/#{route_key}/#{parent_id}/manifest/canvas/#{canvas_id}"
      end

      def iiif_member_canvas_dimension_map(document)
        @iiif_member_canvas_dimension_map ||= {}
        doc_id = document[:id].to_s
        return @iiif_member_canvas_dimension_map[doc_id] if @iiif_member_canvas_dimension_map.key?(doc_id)

        member_ids = Array(document[:member_ids_ssim] || document['member_ids_ssim'])
        member_ids = Array(@parent_document[:member_ids_ssim] || @parent_document['member_ids_ssim']) if member_ids.empty?
        return @iiif_member_canvas_dimension_map[doc_id] = {} if member_ids.empty?

        solr_response = Blacklight.default_index.connection.get(
          'select',
          params: {
            q: "{!terms f=id}#{member_ids.join(',')}",
            rows: member_ids.length,
            fl: 'id,width_is,height_is,file_format_tesim'
          }
        )

        docs = Array(solr_response.dig('response', 'docs'))
        @iiif_member_canvas_dimension_map[doc_id] = docs.each_with_object({}) do |member_doc, map|
          width = member_doc['width_is']
          height = member_doc['height_is']
          next unless width && height

          formats = Array(member_doc['file_format_tesim'])
          next if formats.any? && formats.none? { |format| format.to_s.start_with?('image/') }

          map[[width.to_i, height.to_i]] = member_doc['id']
        end
      rescue StandardError
        @iiif_member_canvas_dimension_map[doc_id] = {}
      end
    end

    module IiifSearchResponseOcrHighlightingDecorator
      def resources
        ocr_highlighting = solr_response['ocrHighlighting']
        return super unless ocr_highlighting.present?

        @total = 0
        solr_response.documents.each do |document|
          doc_id = document[:id].to_s
          doc_ocr = ocr_highlighting[doc_id] || ocr_highlighting[doc_id.to_sym]
          snippet_matches = extract_ocr_matches(doc_ocr)
          if snippet_matches.empty?
            @total += 1
            annotation = IiifSearchAnnotation.new(document,
                                                  solr_response.params['q'],
                                                  0, nil, controller,
                                                  @parent_document)
            annotation.instance_variable_set(:@iiif_canvas_id_override, canvas_id_for_page_index(document, nil))
            @resources << annotation.as_hash
            @hits << { '@type': 'search:Hit', 'annotations': [annotation.annotation_id] }
          else
            snippet_matches.each_with_index do |match, hl_index|
              @total += 1
              annotation = IiifSearchAnnotation.new(document,
                                                    solr_response.params['q'],
                                                    hl_index, match[:text], controller,
                                                    @parent_document)
              annotation.instance_variable_set(
                :@iiif_canvas_id_override,
                canvas_id_for_page_index(document, match[:page_idx], match[:page_dimensions])
              )
              xywh = xywh_from_region(match[:region])
              annotation.define_singleton_method(:coordinates) { xywh ? "#xywh=#{xywh}" : '' }
              @resources << annotation.as_hash
              @hits << { '@type': 'search:Hit', 'annotations': [annotation.annotation_id] }
            end
          end
        end

        @resources
      end

      private

      def iiif_member_canvas_dimension_map(document)
        @iiif_member_canvas_dimension_map ||= {}
        doc_id = document[:id].to_s
        return @iiif_member_canvas_dimension_map[doc_id] if @iiif_member_canvas_dimension_map.key?(doc_id)

        member_ids = Array(document[:member_ids_ssim] || document['member_ids_ssim'])
        member_ids = Array(@parent_document[:member_ids_ssim] || @parent_document['member_ids_ssim']) if member_ids.empty?
        return @iiif_member_canvas_dimension_map[doc_id] = {} if member_ids.empty?

        solr_lookup = Blacklight.default_index.connection.get(
          'select',
          params: {
            q: "{!terms f=id}#{member_ids.join(',')}",
            rows: member_ids.length,
            fl: 'id,width_is,height_is,file_format_tesim'
          }
        )

        docs = Array(solr_lookup.dig('response', 'docs'))
        @iiif_member_canvas_dimension_map[doc_id] = docs.each_with_object({}) do |member_doc, map|
          width = member_doc['width_is']
          height = member_doc['height_is']
          next unless width && height

          map[[width.to_i, height.to_i]] = member_doc['id']
        end
      rescue StandardError
        @iiif_member_canvas_dimension_map[doc_id] = {}
      end

      def extract_ocr_matches(doc_ocr)
        return [] unless doc_ocr.respond_to?(:each_value)

        doc_ocr.each_value.flat_map do |field_payload|
          next [] unless field_payload.respond_to?(:[])

          Array(field_payload['snippets'] || field_payload[:snippets]).flat_map do |snippet|
            next [] unless snippet.is_a?(Hash)

            text = snippet['text'] || snippet[:text]
            next [] unless text

            regions = Array(snippet['regions'] || snippet[:regions])
            default_page_idx = snippet_page_index(snippet)
            page_dimensions = snippet_page_dimensions(snippet, default_page_idx)

            if regions.empty?
              [{ text: text, region: nil, page_idx: default_page_idx, page_dimensions: page_dimensions }]
            else
              regions.filter_map do |region|
                next unless region.is_a?(Hash)

                page_idx = region['pageIdx'] || region[:pageIdx] || default_page_idx
                region_dimensions = snippet_page_dimensions(snippet, page_idx) || page_dimensions
                { text: text, region: region, page_idx: page_idx, page_dimensions: region_dimensions }
              end
            end
          end
        end
      end

      def snippet_page_dimensions(snippet, page_idx)
        pages = Array(snippet['pages'] || snippet[:pages])
        page = pages[page_idx.to_i] if page_idx
        page ||= pages.first
        return nil unless page.is_a?(Hash)

        width = page['width'] || page[:width]
        height = page['height'] || page[:height]
        return nil unless width && height

        [width.to_i, height.to_i]
      end

      def snippet_page_index(snippet)
        pages = Array(snippet['pages'] || snippet[:pages])
        first_page = pages.first
        return nil unless first_page.is_a?(Hash)

        page_id = first_page['id'] || first_page[:id]
        return nil unless page_id

        match = page_id.to_s.match(/page_(\d+)/)
        return nil unless match

        match[1].to_i - 1
      end

      def canvas_id_for_page_index(document, page_idx, page_dimensions = nil)
        if page_dimensions
          canvas_id = iiif_member_canvas_dimension_map(document)[page_dimensions]
          return canvas_id if canvas_id.present?
        end

        member_ids = Array(document[:member_ids_ssim] || document['member_ids_ssim'])
        member_ids = Array(@parent_document[:member_ids_ssim] || @parent_document['member_ids_ssim']) if member_ids.empty?

        if page_idx.is_a?(Numeric)
          member_id = member_ids[page_idx.to_i]
          return member_id if member_id.present?
        end

        member_ids.first.presence || document[:id]
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

  BlacklightIiifSearch::IiifSearchAnnotation.prepend BlacklightIiifSearch::IiifSearchAnnotationManifestCanvasDecorator
  BlacklightIiifSearch::IiifSearchResponse.prepend BlacklightIiifSearch::IiifSearchResponseOcrHighlightingDecorator
end