# frozen_string_literal: true

class IiifBuilders::Ramp < IiifBuilders::Base
  VIEWER = 'ramp'
  DEFAULT_AV_WIDTH = 640
  DEFAULT_AV_HEIGHT = 360
  DEFAULT_AV_DURATION = 1

  private

  def canvases(members)
    source_members(members).select { |member| av_member?(member) }.map do |member|
      media_member = preferred_presentation_member(source: member, members: members)
      next unless media_member

      media_url = download_url(media_member, disposition: :inline)
      next if media_url.blank?

      canvas_id = canvas_id_for(member)
      annotation_page_id = "#{canvas_id}/page"
      annotation_id = "#{annotation_page_id}/annotation"

      {
        'id' => canvas_id,
        'type' => 'Canvas',
        'label' => language_map(label_for(member)),
        'height' => dimension_for(media_member, 'height_is') || DEFAULT_AV_HEIGHT,
        'width' => dimension_for(media_member, 'width_is') || DEFAULT_AV_WIDTH,
        'duration' => duration_for(media_member) || duration_for(member) || DEFAULT_AV_DURATION,
        'items' => [
          {
            'id' => annotation_page_id,
            'type' => 'AnnotationPage',
            'items' => [
              {
                'id' => annotation_id,
                'type' => 'Annotation',
                'motivation' => 'painting',
                'body' => media_body(media_member, media_url),
                'target' => canvas_id
              }
            ]
          }
        ],
        'annotations' => transcript_annotation_pages(source: member, members: members, canvas_id: canvas_id)
      }.compact
    end.compact
  end

  def media_body(member, media_url)
    mime = effective_mime_type_for(member)
    {
      'id' => media_url,
      'type' => mime.start_with?(AUDIO_MIME_PREFIX) ? 'Sound' : 'Video',
      'format' => mime.presence || 'video/mp4',
      'label' => language_map(label_for(member))
    }
  end

  def transcript_annotation_pages(source:, members:, canvas_id:)
    transcripts = Resolvers::DerivativeLinkResolver.new(members: members).transcript_members_for(source.id)
    return [] if transcripts.empty?

    items = transcripts.filter_map do |transcript|
      transcript_url = download_url(transcript, format: :vtt)
      next if transcript_url.blank?

      {
        'id' => "#{canvas_id}/supplementing/#{transcript.id}",
        'type' => 'Annotation',
        'motivation' => 'supplementing',
        'body' => {
          'id' => transcript_url,
          'type' => 'Text',
          'format' => VTT_MIME_TYPE,
          'label' => language_map(label_for(transcript).presence || 'Transcript')
        },
        'target' => canvas_id
      }
    end
    return [] if items.empty?

    [
      {
        'id' => "#{canvas_id}/supplementing",
        'type' => 'AnnotationPage',
        'items' => items
      }
    ]
  end

  def av_member?(member)
    return true if safe_public_send(member, :audio?)
    return true if safe_public_send(member, :video?)

    mime = effective_mime_type_for(member)
    return true if mime.start_with?(*AUDIO_VISUAL_MIME_PREFIXES)

    AUDIO_VISUAL_EXTENSIONS_WITH_DOT.any? { |extension| label_for(member).downcase.end_with?(extension) }
  end

  def duration_for(member)
    %w[duration_dtsim duration_f duration_ssi duration_tesim].each do |field|
      value = solr_value(member, field)
      next if value.blank?

      numeric = Array(value).first.to_f
      next unless numeric.positive?

      return normalize_duration_value(numeric)
    end

    nil
  end

  def normalize_duration_value(value)
    value > 10_000 ? (value / 1000.0) : value
  end
end
