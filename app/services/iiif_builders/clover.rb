# frozen_string_literal: true

class IiifBuilders::Clover < IiifBuilders::Base
  VIEWER = 'clover'
  DEFAULT_IMAGE_WIDTH = 1200
  DEFAULT_IMAGE_HEIGHT = 1600

  private

  def base_manifest(presenter)
    manifest = super
    service = search_service(presenter)
    manifest['service'] = [service] if service.present?
    manifest
  end

  def canvases(members)
    source_members(members).select { |member| image_member?(member) }.map do |member|
      image_member = preferred_presentation_member(source: member, members: members)
      next unless image_member

      service_id = iiif_image_service_id(member)
      next if service_id.blank?

      width = dimension_for(image_member, 'width_is') || dimension_for(member, 'width_is') || DEFAULT_IMAGE_WIDTH
      height = dimension_for(image_member, 'height_is') || dimension_for(member, 'height_is') || DEFAULT_IMAGE_HEIGHT
      canvas_id = canvas_id_for(member)
      annotation_page_id = "#{canvas_id}/page"
      annotation_id = "#{annotation_page_id}/annotation"

      {
        'id' => canvas_id,
        'type' => 'Canvas',
        'label' => language_map(label_for(member)),
        'height' => height,
        'width' => width,
        'items' => [
          {
            'id' => annotation_page_id,
            'type' => 'AnnotationPage',
            'items' => [
              {
                'id' => annotation_id,
                'type' => 'Annotation',
                'motivation' => 'painting',
                'body' => image_body(image_member, service_id, width: width, height: height),
                'target' => canvas_id
              }
            ]
          }
        ]
      }
    end.compact
  end

  def image_body(member, service_id, width:, height:)
    image_url = "#{service_id}/full/#{Hyrax.config.iiif_image_size_default},/0/default.jpg"
    {
      'id' => image_url,
      'type' => 'Image',
      'format' => effective_mime_type_for(member).presence || 'image/jpeg',
      'height' => height,
      'width' => width,
      'service' => [
        {
          'id' => service_id,
          'type' => 'ImageService2',
          'profile' => 'level2'
        }
      ]
    }
  end

  def search_service(presenter)
    return nil if presenter_id(presenter).blank?

    {
      'id' => Rails.application.routes.url_helpers.solr_document_iiif_search_url(
        solr_document_id: presenter_id(presenter),
        host: hostname_for(presenter)
      ),
      'type' => 'SearchService1',
      'profile' => 'http://iiif.io/api/search/1/search'
    }
  rescue StandardError
    nil
  end
end
