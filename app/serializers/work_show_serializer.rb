# frozen_string_literal: true

class WorkShowSerializer
  THUMBNAIL_RESOLUTION_MEMBER_LIMIT = 80

  include Constants::FileExtensionConstants
  include Constants::MimeTypeConstants

  attr_reader :presenter, :view_context

  def self.can_view_service_files?(view_context)
    user = view_context.current_user
    return false unless user
    return true if user.respond_to?(:admin?) && user.admin?
    return false unless user.respond_to?(:roles)

    admin_role_names = [Hyrax.config.admin_user_group_name, 'admin'].compact.uniq
    user.roles.where(name: admin_role_names).exists?
  rescue StandardError
    false
  end

  def initialize(presenter:, view_context:)
    @presenter = presenter
    @view_context = view_context
  end

  def as_json
    can_edit_work = view_context.can?(:edit, presenter)
    can_view_service_files = self.class.can_view_service_files?(view_context)
    original_members = original_item_members
    visible_service_members = can_view_service_files ? service_item_members : []
    original_thumbnail_urls = thumbnail_urls_for_members(original_members, service_item_members)
    service_thumbnail_urls = thumbnail_urls_for_members(visible_service_members, service_item_members)

    {
      id: presenter.id.to_s,
      title: presenter.title.to_a.first.to_s,
      descriptions: Array(presenter.description).map(&:to_s),
      originalMembers: serialize_members(original_members, can_edit_work, thumbnail_urls: original_thumbnail_urls),
      serviceMembers: serialize_members(visible_service_members, can_edit_work, thumbnail_urls: service_thumbnail_urls),
      canViewServiceFiles: can_view_service_files
    }
  end

  private

  def serialize_members(members, can_edit, thumbnail_urls: {})
    members
      .map do |member|
        serialize_member(
          member,
          can_edit: can_edit,
          thumbnail_url: thumbnail_urls[member.id.to_s]
        )
      end
      .sort_by { |member| member[:label].to_s.downcase }
  end

  def serialize_member(member, can_edit:, thumbnail_url: nil)
    label = member_label(member)
    mime_type = member_mime_type(member)
    is_audio_visual = member_audio_visual?(member, mime_type)
    is_pdf = member_pdf?(member, label, mime_type)
    is_image = member_image?(member, label, mime_type)
    download_url = download_path_for_member(member)

    {
      id: member.id.to_s,
      label: label,
      sourceFileSetId: source_file_set_id(member),
      dateUploaded: (member.respond_to?(:date_uploaded) ? Array(member.date_uploaded).first.to_s : ''),
      visibility: (member.respond_to?(:visibility) ? member.visibility.to_s : ''),
      showUrl: Rails.application.routes.url_helpers.hyrax_file_set_path(member.id),
      downloadUrl: download_url,
      thumbnailUrl: thumbnail_url,
      editUrl: (Rails.application.routes.url_helpers.edit_hyrax_file_set_path(member.id) if can_edit),
      isAudioVisual: is_audio_visual,
      isPdf: is_pdf,
      isImage: is_image,
      isReadingModePdf: reading_mode_pdf_member?(member),
      pdfUrl: (download_url if is_pdf),
      hocrUrl: nil,
      isRepresentativeThumbnail: representative_thumbnail_member?(member)
    }
  end

  def download_path_for_member(member)
    Hyrax::Engine.routes.url_helpers.download_path(id: member.id, locale: nil)
  end

  def member_label(member)
    label = member.title.to_a.first.to_s if member.respond_to?(:title)
    label = member.label.to_s if label.blank? && member.respond_to?(:label)
    label.to_s
  end

  def member_mime_type(member)
    return member.mime_type.to_s.downcase if member.respond_to?(:mime_type)

    source = member.respond_to?(:model) ? member.model : member
    original_file = source.respond_to?(:original_file) ? source.original_file : nil
    original_file&.mime_type.to_s.downcase
  end

  def member_audio_visual?(member, mime_type)
    return true if member.respond_to?(:audio?) && member.audio?
    return true if member.respond_to?(:video?) && member.video?
    return true if AUDIO_VISUAL_EXTENSIONS_WITH_DOT.any? { |extension| member_label(member).to_s.downcase.end_with?(extension) }

    mime_type.start_with?(*AUDIO_VISUAL_MIME_PREFIXES)
  end

  def member_pdf?(member, label, mime_type)
    return true if member.respond_to?(:pdf?) && member.pdf?
    return true if mime_type == PDF_MIME_TYPE

    label.to_s.downcase.end_with?('.pdf')
  end

  def member_image?(member, label, mime_type)
    return true if member.respond_to?(:image?) && member.image?
    return true if mime_type.start_with?(IMAGE_MIME_PREFIX)

    downcased_label = label.to_s.downcase
    IMAGE_EXTENSIONS_WITH_DOT.any? { |extension| downcased_label.end_with?(extension) }
  end

  def representative_thumbnail_member?(member)
    return false unless service_member?(member)

    return true if representative_thumbnail_tagged_member?(member)
    return true if representative_thumbnail_filename?(member)
    return false unless presenter.respond_to?(:thumbnail_id)
    return false if presenter.thumbnail_id.blank?
    return false unless member.id.to_s == presenter.thumbnail_id.to_s

    DerivativeLinkResolver.related_url_values_for(member).include?(Constants::ThumbnailTagConstants::THUMBNAIL_DERIVATIVE_TAG)
  end

  def representative_thumbnail_tagged_member?(member)
    DerivativeLinkResolver.related_url_values_for(member).any? do |value|
      value.start_with?(Constants::ThumbnailTagConstants::REPRESENTATIVE_THUMBNAIL_TAG_PREFIX)
    end
  end

  def representative_thumbnail_filename?(member)
    member_label(member).to_s.casecmp?(Constants::ThumbnailFilenameConstants::REPRESENTATIVE_THUMBNAIL_FILENAME)
  end

  def source_file_set_id(member)
    DerivativeLinkResolver.source_file_set_id_for(member)
  end

  def thumbnail_urls_for_members(members, service_members)
    candidate_members = Array(members).select { |member| thumbnail_candidate_member?(member) }
    return {} if candidate_members.empty?

    if candidate_members.length > THUMBNAIL_RESOLUTION_MEMBER_LIMIT
      return candidate_members.each_with_object({}) do |member, map|
        map[member.id.to_s] = fallback_thumbnail_path_for(member)
      end
    end

    thumbnail_resolver.thumbnail_paths_by_member_id(
      members: candidate_members,
      service_members: service_members
    )
  end

  def fallback_thumbnail_path_for(member)
    Hyrax::Engine.routes.url_helpers.download_path(id: member.id, file: 'thumbnail', locale: nil)
  end

  def thumbnail_candidate_member?(member)
    label = member_label(member)
    mime_type = member_mime_type(member)

    member_audio_visual?(member, mime_type) ||
      member_pdf?(member, label, mime_type) ||
      member_image?(member, label, mime_type) ||
      representative_thumbnail_member?(member)
  end

  def original_item_members
    @original_item_members ||= presenter.original_item_members
  end

  def service_item_members
    @service_item_members ||= presenter.service_item_members
  end

  def thumbnail_resolver
    @thumbnail_resolver ||= ThumbnailResolver.new
  end

  def reading_mode_pdf_member?(member)
    return false unless member.respond_to?(:id)
    return false unless member_pdf?(member, member_label(member), member_mime_type(member))
    return false unless service_member?(member)

    reading_mode_pdf_filename?(member)
  end

  def reading_mode_pdf_filename?(member)
    return false unless member_pdf?(member, member_label(member), member_mime_type(member))

    member_label(member).to_s == Constants::DerivativeFilenameConstants::READING_MODE_PDF_FILENAME
  end

  def service_member?(member)
    return ActiveModel::Type::Boolean.new.cast(member.solr_document['service_file_bsi']) if member.respond_to?(:solr_document)

    source = member.respond_to?(:model) ? member.model : member
    source.respond_to?(:service_file) && ActiveModel::Type::Boolean.new.cast(source.service_file)
  end
end