# frozen_string_literal: true

require 'json'

class IiifBuilders::Base
  include ::Derivatives::Constants::FileExtensionConstants
  include ::Derivatives::Constants::MimeTypeConstants
  include ::Derivatives::Constants::ThumbnailTagConstants
  include StringNormalization

  GENERIC_OCTET_STREAM_MIME_TYPE = 'application/octet-stream'

  def manifest_json_for(presenter:)
    JSON.generate(manifest_for(presenter: presenter))
  end

  def manifest_for(presenter:)
    @manifest_host = hostname_for(presenter)
    members = all_member_presenters(presenter)
    manifest = base_manifest(presenter)

    manifest['items'] = canvases(members)
    manifest['thumbnail'] = manifest_thumbnail(presenter, members)

    manifest.compact
  end

  private

  def base_manifest(presenter)
    {
      '@context' => 'http://iiif.io/api/presentation/3/context.json',
      'id' => manifest_url(presenter, variant: self.class::VIEWER),
      'type' => 'Manifest',
      'label' => language_map(title_for(presenter))
    }
  end

  def canvases(members)
    raise NotImplementedError, "#{self.class} must implement #canvases"
  end

  def manifest_thumbnail(presenter, members)
    thumbnail_member = members.find { |member| member.id.to_s == safe_public_send(presenter, :thumbnail_id).to_s }
    thumbnail_member ||= source_members(members).find { |member| image_member?(member) }
    return nil unless thumbnail_member

    thumbnail_url = if image_member?(thumbnail_member)
                      image_member = service_member?(thumbnail_member) ? thumbnail_member : preferred_presentation_member(source: thumbnail_member, members: members)
                      service_id = iiif_image_service_id(image_member) if image_member
                      "#{service_id}/full/!300,300/0/default.jpg" if service_id.present?
                    elsif service_member?(thumbnail_member)
                      download_url(thumbnail_member, file: 'thumbnail')
                    end
    return nil if thumbnail_url.blank?

    [{ 'id' => thumbnail_url, 'type' => 'Image' }]
  end

  def preferred_presentation_member(source:, members:)
    service_members(members).find do |candidate|
      Resolvers::DerivativeLinkResolver.source_file_set_id_for(candidate) == source.id.to_s && presentation_member?(candidate)
    end
  end

  def presentation_member?(member)
    filename = label_for(member).downcase
    return true if filename.include?('_presentation-version.') || filename.include?('_presentation_version.')

    Resolvers::DerivativeLinkResolver.related_url_values_for(member).any? do |value|
      value == "#{THUMBNAIL_DERIVATIVE_PREFIX}presentation-version" ||
        value == "#{THUMBNAIL_DERIVATIVE_PREFIX}presentation_version"
    end
  end

  def all_member_presenters(presenter)
    ids = Array(safe_public_send(presenter, :member_ids)).map(&:to_s)
    return Array(presenter.member_presenters(ids)).compact if ids.present? && presenter.respond_to?(:member_presenters)
    return Array(presenter.member_presenters).compact if presenter.respond_to?(:member_presenters)

    []
  rescue ArgumentError
    Array(presenter.member_presenters).compact
  end

  def source_members(members)
    members.reject { |member| service_member?(member) || representative_thumbnail_member?(member) }
  end

  def service_members(members)
    members.select { |member| service_member?(member) }
  end

  def service_member?(member)
    value = source_for(member).service_file if source_for(member).respond_to?(:service_file)
    value = solr_value(member, 'service_file_bsi') if value.nil?
    ActiveModel::Type::Boolean.new.cast(value)
  end

  def representative_thumbnail_member?(member)
    Resolvers::DerivativeLinkResolver.related_url_values_for(member).any? do |value|
      value == THUMBNAIL_DERIVATIVE_TAG || value.start_with?(REPRESENTATIVE_THUMBNAIL_TAG_PREFIX)
    end
  end

  def image_member?(member)
    return true if safe_public_send(member, :image?)

    mime = effective_mime_type_for(member)
    return true if mime.start_with?(IMAGE_MIME_PREFIX)

    IMAGE_EXTENSIONS_WITH_DOT.any? { |extension| label_for(member).downcase.end_with?(extension) }
  end

  def effective_mime_type_for(member)
    presenter_mime = normalize_mime_type(safe_public_send(member, :mime_type).to_s)
    return presenter_mime if specific_mime_type?(presenter_mime)

    original_file = original_file_for(member)
    file_mime = normalize_mime_type(original_file&.mime_type.to_s)
    return file_mime if specific_mime_type?(file_mime)

    inferred_mime_type(label_for(member)).presence || presenter_mime.presence || file_mime.to_s
  end

  def specific_mime_type?(mime)
    mime.present? && mime != GENERIC_OCTET_STREAM_MIME_TYPE
  end

  def inferred_mime_type(filename)
    normalized = filename.to_s.downcase
    return "#{AUDIO_MIME_PREFIX}mpeg" if normalized.end_with?('.mp3')
    return "#{AUDIO_MIME_PREFIX}wav" if normalized.end_with?('.wav')
    return "#{AUDIO_MIME_PREFIX}mp4" if normalized.end_with?('.m4a')
    return "#{VIDEO_MIME_PREFIX}mp4" if normalized.end_with?('.mp4', '.m4v')
    return "#{VIDEO_MIME_PREFIX}quicktime" if normalized.end_with?('.mov')
    return "#{VIDEO_MIME_PREFIX}webm" if normalized.end_with?('.webm')
    return "#{IMAGE_MIME_PREFIX}jpeg" if normalized.end_with?('.jpg', '.jpeg')
    return "#{IMAGE_MIME_PREFIX}png" if normalized.end_with?('.png')
    return "#{IMAGE_MIME_PREFIX}tiff" if normalized.end_with?('.tif', '.tiff')

    ''
  end

  def dimension_for(member, field)
    value = solr_value(member, field)
    numeric = Array(value).first.to_i
    numeric.positive? ? numeric : nil
  end

  def iiif_image_service_id(member)
    Hyrax.config.iiif_info_url_builder.call(member.id, hostname_for(member))
  rescue StandardError
    nil
  end

  def download_url(member, format: nil, file: nil, disposition: nil)
    options = { id: member.id, host: hostname_for(member), locale: nil }
    options[:format] = format if format
    options[:file] = file if file
    options[:disposition] = disposition if disposition
    Hyrax::Engine.routes.url_helpers.download_url(options)
  rescue StandardError
    nil
  end

  def manifest_url(presenter, variant:)
    base_url = explicit_manifest_url_for(presenter).presence || routed_manifest_url_for(presenter).presence || fallback_manifest_url_for(presenter)
    return '' if base_url.blank?

    "#{base_url.sub(/\?.*\z/, '')}?viewer=#{variant}"
  end

  def explicit_manifest_url_for(presenter)
    safe_public_send(presenter, :manifest_url).to_s
  end

  def routed_manifest_url_for(presenter)
    Rails.application.routes.url_helpers.polymorphic_url([:manifest, presenter], host: hostname_for(presenter), locale: nil)
  rescue StandardError
    ''
  end

  def fallback_manifest_url_for(presenter)
    route_key = work_route_key_for(presenter)
    return '' if route_key.blank? || presenter_id(presenter).blank?

    protocol = Rails.application.routes.default_url_options[:protocol].presence || 'http'
    protocol = protocol.to_s.delete_suffix('://')
    "#{protocol}://#{hostname_for(presenter)}/concern/#{route_key}/#{presenter_id(presenter)}/manifest"
  end

  def work_route_key_for(presenter)
    model_name = safe_public_send(presenter, :model_name)
    route_key = safe_public_send(model_name, :route_key)
    return route_key if route_key.present?

    model_name = safe_public_send(source_for(presenter), :model_name)
    route_key = safe_public_send(model_name, :route_key)
    return route_key if route_key.present?

    model_class_name = Array(solr_value(presenter, 'has_model_ssim')).first.to_s
    model_class_name.underscore.pluralize if model_class_name.present?
  end

  def canvas_id_for(member)
    "/canvas/#{member.id}"
  end

  def title_for(presenter)
    value = safe_public_send(presenter, :title)
    Array(value).first.to_s.presence || presenter_id(presenter).presence || 'Untitled Work'
  end

  def label_for(member)
    original_filename = original_file_for(member)&.original_filename.to_s
    return original_filename if original_filename.present?

    label = safe_public_send(member, :label).to_s
    return label if label.present?

    title = safe_public_send(member, :title)
    Array(title).first.to_s
  end

  def language_map(value)
    { 'none' => [value.to_s] }
  end

  def hostname_for(object)
    host = safe_public_send(object, :hostname).presence || safe_public_send(object, :host_name).presence
    host.presence || @manifest_host.presence || Rails.application.routes.default_url_options[:host]
  end

  def presenter_id(presenter)
    safe_public_send(presenter, :id).to_s
  end

  def source_for(member)
    member.respond_to?(:model) ? member.model : member
  end

  def original_file_for(member)
    source = source_for(member)
    source.original_file if source.respond_to?(:original_file)
  end

  def solr_value(member, field)
    if member.respond_to?(:solr_document) && member.solr_document.respond_to?(:[])
      return member.solr_document[field]
    end

    source = source_for(member)
    source[field] if source.respond_to?(:[])
  rescue StandardError
    nil
  end

  def safe_public_send(object, method_name)
    return nil unless object.respond_to?(method_name)

    object.public_send(method_name)
  rescue StandardError
    nil
  end
end
