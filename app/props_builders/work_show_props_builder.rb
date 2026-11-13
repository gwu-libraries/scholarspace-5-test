# frozen_string_literal: true

# Builds the React WorkShow props from a Hyrax presenter and view context.
class WorkShowPropsBuilder
  THUMBNAIL_RESOLUTION_MEMBER_LIMIT = 80
  VIEWER_TYPE_RAMP = 'ramp'
  VIEWER_TYPE_PDF_OR_IMAGES = 'pdf_or_images'
  VIEWER_TYPE_CLOVER = 'clover'
  VIEWER_ADMIN_ROLE_NAMES = %w[admin content-admin].freeze

  include ::Derivatives::Constants::FileExtensionConstants
  include ::Derivatives::Constants::DerivativeTypeConstants
  include ::Derivatives::Constants::MimeTypeConstants
  include ::Derivatives::Constants::ThumbnailTagConstants
  include Derivatives::SourceFiles::SourceFileSetMimeDetection

  attr_reader :presenter, :view_context

  def self.can_view_service_files?(view_context)
    user = view_context.current_user
    return false unless user
    return true if user.respond_to?(:admin?) && user.admin?
    return false unless user.respond_to?(:roles)

    admin_role_names = ([Hyrax.config.admin_user_group_name] + VIEWER_ADMIN_ROLE_NAMES).compact.uniq
    user.roles.where(name: admin_role_names).exists?
  rescue StandardError
    false
  end

  def initialize(presenter:, view_context:)
    @presenter = presenter
    @view_context = view_context
  end

  def build
    can_edit_work = view_context.can?(:edit, presenter)
    can_view_service_files = self.class.can_view_service_files?(view_context)
    original_members = original_item_members
    visible_service_members = can_view_service_files ? service_item_members : []
    original_thumbnail_urls = thumbnail_urls_for_members(original_members, service_item_members)
    service_thumbnail_urls = thumbnail_urls_for_members(visible_service_members, service_item_members)

    {
      id: presenter.id.to_s,
      title: presenter.title.to_a.first.to_s,
      metadata: metadata_payload,
      viewer: viewer_payload,
      readingModePdf: reading_mode_pdf_payload,
      originalMembers: serialize_members(original_members, can_edit_work, thumbnail_urls: original_thumbnail_urls),
      serviceMembers: serialize_members(visible_service_members, can_edit_work, thumbnail_urls: service_thumbnail_urls),
      canViewServiceFiles: can_view_service_files
    }
  end

  private

  def reading_mode_pdf_payload
    member = service_item_members.find { |candidate| reading_mode_pdf_member?(candidate) }
    return nil unless member

    {
      fileUrl: download_url_for_member(member, is_pdf: true),
      hocrUrl: view_context.hocr_download_url_for_work(presenter, pdf_file_id: member.id)
    }
  end

  def metadata_payload
    show_fields = I18n.t('blacklight.search.fields.show', default: {}).keys.map(&:to_s)
    fields = (show_fields + %w[
      description_tesim abstract_tesim creator_tesim gw_affiliation_tesim doi_tesim
      bulkrax_identifier_tesim degree_tesim advisor_tesim committee_member_tesim
    ]).uniq - %w[title_tesim]
    document = presenter.respond_to?(:solr_document) ? presenter.solr_document : {}

    fields.filter_map do |field|
      values = metadata_values(document, field)
      next if values.empty?

      {
        name: field,
        label: I18n.t("blacklight.search.fields.show.#{field}", default: field.delete_suffix('_tesim').delete_suffix('_dtsi').humanize),
        values: values
      }
    end
  end

  def metadata_values(document, field)
    values = Array(document[field])
    values = presenter.description if values.empty? && field == 'description_tesim'
    values = presenter.abstract if values.empty? && field == 'abstract_tesim' && presenter.respond_to?(:abstract)
    values.reject(&:blank?).map(&:to_s)
  end

  def viewer_payload
    pdf_id = pdf_viewer_file_id
    has_images = original_item_members.any? { |member| displayable_image_member?(member) }
    has_pdfs = pdf_id.present?

    return ramp_viewer_payload if av_only_work?(has_images: has_images, has_pdfs: has_pdfs)
    return clover_viewer_payload if image_only_work?(has_images: has_images, has_pdfs: has_pdfs)
    return pdf_or_images_viewer_payload(pdf_id) if has_pdfs

    no_viewer_payload
  end

  def av_only_work?(has_images:, has_pdfs:)
    (representative_av? || av_member_present?) && !has_images && !has_pdfs
  end

  def image_only_work?(has_images:, has_pdfs:)
    has_images && !has_pdfs
  end

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
    download_url = download_url_for_member(member, is_pdf: is_pdf)

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
      canvasId: member_canvas_id(member, is_av: is_audio_visual, is_image: is_image),
      pdfUrl: (download_url if is_pdf),
      hocrUrl: (view_context.hocr_download_url_for_work(presenter, pdf_file_id: member.id) if is_pdf),
      isRepresentativeThumbnail: representative_thumbnail_member?(member)
    }
  end

  def download_url_for_member(member, is_pdf: false)
    preferred_url = view_context.preferred_download_url_for_member(presenter, member.id)
    return preferred_url if preferred_url.present?
    return nil unless is_pdf

    pdfjs_member = pdfjs_member_for(member)
    return nil unless pdfjs_member

    view_context.pdf_download_url_for_file(pdfjs_member.id)
  end

  def pdfjs_member_for(member)
    return member if reading_mode_pdf_member?(member)
    return member if presentation_version_pdf_member?(member)
    return nil if service_member?(member)

    service_item_members.find do |candidate|
      presentation_version_pdf_member?(candidate) && source_file_set_id(candidate) == member.id.to_s
    end
  end

  def member_canvas_id(member, is_av:, is_image:)
    return nil unless is_av || is_image

    # Both AV (RAMP startCanvasId) and images (Clover focus) use IIIF v3 canvas
    # ids from the manifest (`/canvas/<id>`), not legacy absolute manifest/canvas
    # urls. This keeps viewer focus IDs aligned with manifest `items[].id`.
    if presenter.respond_to?(:canvas_index_for_member)
      index = presenter.canvas_index_for_member(member.id)
      return "/canvas/#{member.id}" if index.present?
    end

    # Fallback for images not in the presenter's canvas index.
    if is_image
      image_members = original_item_members.select { |m| member_image?(m, member_label(m), member_mime_type(m)) }
      return "/canvas/#{member.id}" if image_members.any? { |m| m.id.to_s == member.id.to_s }
    end

    nil
  end

  def representative_av?
    representative = presenter.representative_presenter
    representative.present? && displayable_av_member?(representative)
  end

  def av_member_present?
    original_item_members.any? do |member|
      displayable_av_member?(member)
    end
  end

  def displayable_av_member?(member)
    member_audio_visual?(member, member_mime_type(member)) && presentation_download_url_for_member(member).present?
  end

  def displayable_image_member?(member)
    member_image?(member, member_label(member), member_mime_type(member)) && presentation_download_url_for_member(member).present?
  end

  def presentation_download_url_for_member(member)
    return nil unless member.respond_to?(:id)

    view_context.preferred_download_url_for_member(presenter, member.id)
  end

  def pdf_viewer_file_id
    @pdf_viewer_file_id ||= view_context.pdf_viewer_file_id_for_work(presenter)
  end

  def ramp_viewer_payload
    {
      type: VIEWER_TYPE_RAMP,
      manifestUrl: manifest_urls[:ramp],
      rampManifestUrl: manifest_urls[:ramp],
      cloverManifestUrl: manifest_urls[:clover],
      transcriptFiles: transcript_files_payload
    }
  end

  def pdf_or_images_viewer_payload(pdf_id)
    {
      type: VIEWER_TYPE_PDF_OR_IMAGES,
      hasImages: view_context.has_images_for_work?(presenter),
      defaultViewer: view_context.default_viewer_for_work(presenter),
      pdfUrl: view_context.pdf_download_url_for_file(pdf_id),
      hocrUrl: view_context.hocr_download_url_for_work(presenter, pdf_file_id: pdf_id),
      manifestUrl: manifest_urls[:clover],
      rampManifestUrl: manifest_urls[:ramp],
      cloverManifestUrl: manifest_urls[:clover],
      transcriptFiles: transcript_files_payload
    }
  end

  def clover_viewer_payload
    {
      type: VIEWER_TYPE_CLOVER,
      manifestUrl: manifest_urls[:clover],
      rampManifestUrl: manifest_urls[:ramp],
      cloverManifestUrl: manifest_urls[:clover],
      transcriptFiles: transcript_files_payload
    }
  end

  def no_viewer_payload
    {
      type: 'none',
      transcriptFiles: transcript_files_payload
    }
  end

  def transcript_files_payload
    return [] unless presenter.respond_to?(:transcript_files)

    Array(presenter.transcript_files)
  end

  def manifest_urls
    @manifest_urls ||= {
      default: view_context.manifest_url_for_work(presenter),
      ramp: view_context.ramp_manifest_url_for_work(presenter),
      clover: view_context.clover_manifest_url_for_work(presenter)
    }
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

  def member_looks_like_av_source?(member)
    file_set = member.respond_to?(:model) ? member.model : member
    return false unless file_set.respond_to?(:original_file)

    source_audio_visual_file_set?(file_set)
  rescue StandardError
    false
  end

  def member_audio_visual?(member, mime_type)
    return true if member.respond_to?(:audio?) && member.audio?
    return true if member.respond_to?(:video?) && member.video?
    return true if AUDIO_VISUAL_EXTENSIONS_WITH_DOT.any? { |extension| member_label(member).to_s.downcase.end_with?(extension) }
    return true if member_looks_like_av_source?(member)

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

    Resolvers::DerivativeLinkResolver.related_url_values_for(member).include?(::Derivatives::Constants::ThumbnailTagConstants::THUMBNAIL_DERIVATIVE_TAG)
  end

  def representative_thumbnail_tagged_member?(member)
    Resolvers::DerivativeLinkResolver.related_url_values_for(member).any? do |value|
      value.start_with?(::Derivatives::Constants::ThumbnailTagConstants::REPRESENTATIVE_THUMBNAIL_TAG_PREFIX)
    end
  end

  def representative_thumbnail_filename?(member)
    member_label(member).to_s.casecmp?(::Derivatives::Constants::ThumbnailFilenameConstants::REPRESENTATIVE_THUMBNAIL_FILENAME)
  end

  def source_file_set_id(member)
    Resolvers::DerivativeLinkResolver.source_file_set_id_for(member)
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
    @thumbnail_resolver ||= Resolvers::ThumbnailResolver.new
  end

  def reading_mode_pdf_member?(member)
    return false unless member.respond_to?(:id)
    return false unless member_pdf?(member, member_label(member), member_mime_type(member))
    return false unless service_member?(member)

    reading_mode_pdf_filename?(member)
  end

  def presentation_version_pdf_member?(member)
    return false unless member.respond_to?(:id)
    return false unless member_pdf?(member, member_label(member), member_mime_type(member))
    return false unless service_member?(member)

    Resolvers::DerivativeLinkResolver.related_url_values_for(member).include?("#{THUMBNAIL_DERIVATIVE_PREFIX}#{DERIVATIVE_TYPE_PRESENTATION_VERSION}")
  end

  def reading_mode_pdf_filename?(member)
    return false unless member_pdf?(member, member_label(member), member_mime_type(member))

    member_label(member).to_s == ::Derivatives::Constants::DerivativeFilenameConstants::READING_MODE_PDF_FILENAME
  end

  def service_member?(member)
    return ActiveModel::Type::Boolean.new.cast(member.solr_document['service_file_bsi']) if member.respond_to?(:solr_document)

    source = member.respond_to?(:model) ? member.model : member
    source.respond_to?(:service_file) && ActiveModel::Type::Boolean.new.cast(source.service_file)
  end
end
