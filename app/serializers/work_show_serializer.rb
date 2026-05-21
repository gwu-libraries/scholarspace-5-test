# frozen_string_literal: true

class WorkShowSerializer
  VIEWER_TYPE_RAMP = 'ramp'
  VIEWER_TYPE_PDF_OR_IMAGES = 'pdf_or_images'
  VIEWER_TYPE_CLOVER = 'clover'

  AV_EXTENSIONS = %w[.mp3 .wav .m4a .aac .flac .ogg .oga .mp4 .m4v .mov .avi .mkv .webm .mpeg .mpg].freeze
  IMAGE_EXTENSIONS = %w[.jpg .jpeg .png .gif .tif .tiff .webp .jp2].freeze

  # this is used for consuming the presenter for a work and serializing it into props that
  # are then passed to the WorkShow component, which in turn renders the av/pdf/image viewers.

  # kind of the contract/connection between a normal Hyrax setup and our react-on-rails setup. 

  attr_reader :presenter, :view_context

  def initialize(presenter:, view_context:)
    @presenter = presenter
    @view_context = view_context
  end

  def as_json
    can_edit_work = view_context.can?(:edit, presenter)

    {
      id: presenter.id.to_s,
      title: presenter.title.to_a.first.to_s,
      descriptions: Array(presenter.description).map(&:to_s),
      viewer: viewer_payload,
      originalMembers: serialize_members(presenter.original_item_members, can_edit_work),
      serviceMembers: serialize_members(presenter.service_item_members, can_edit_work),
      canViewServiceFiles: can_view_service_files?
    }
  end

  private

  def viewer_payload
    return ramp_viewer_payload if representative_av?

    pdf_id = pdf_viewer_file_id
    has_images = presenter.original_item_members.any? { |m| member_image?(m, member_label(m), member_mime_type(m)) }
    has_pdfs = presenter.original_item_members.any? { |m| member_pdf?(m, member_label(m), member_mime_type(m)) }

    # If there are images but no PDFs, force Clover viewer
    if has_images && !has_pdfs
      return clover_viewer_payload
    end

    return pdf_or_images_viewer_payload(pdf_id) if pdf_id.present?

    clover_viewer_payload
  end

  # we don't show the service files to non admins. 
  # they aren't 'private', but they don't show up in searches
  # and the tab to view them on a work page doesn't show up either
  def can_view_service_files?
    user = view_context.current_user
    user.present? &&
      user.respond_to?(:roles) &&
      user.roles.where(name: ['admin', 'content-admin']).exists?
  end

  def serialize_members(members, can_edit)
    members
      .map { |member| serialize_member(member, can_edit: can_edit) }
      .sort_by { |member| member[:label].to_s.downcase }
  end

  def serialize_member(member, can_edit:)
    label = member_label(member)
    mime_type = member_mime_type(member)
    is_av = member_audio_video?(member, mime_type)
    is_pdf = member_pdf?(member, label, mime_type)
    is_image = member_image?(member, label, mime_type)
    download_url = Hyrax::Engine.routes.url_helpers.download_path(id: member.id, locale: nil)

    {
      id: member.id.to_s,
      label: label,
      dateUploaded: (member.respond_to?(:date_uploaded) ? Array(member.date_uploaded).first.to_s : ''),
      visibility: (member.respond_to?(:visibility) ? member.visibility.to_s : ''),
      showUrl: Rails.application.routes.url_helpers.hyrax_file_set_path(member.id),
      downloadUrl: download_url,
      editUrl: (Rails.application.routes.url_helpers.edit_hyrax_file_set_path(member.id) if can_edit),
      isAv: is_av,
      isPdf: is_pdf,
      isImage: is_image,
      canvasId: member_canvas_id(member, is_av: is_av, is_image: is_image),
      pdfUrl: (download_url if is_pdf),
      hocrUrl: (view_context.hocr_download_url_for_work(presenter, pdf_file_id: member.id) if is_pdf),
      isRepresentativeThumbnail: representative_thumbnail_member?(member)
    }
  end

  def member_canvas_id(member, is_av:, is_image:)
    return nil unless is_av || is_image

    # Both AV (RAMP startCanvasId) and images (Clover focus) use the canonical
    # IIIF canvas URL keyed by member id.
    #
    # NOTE: viewer.transcriptFiles[n].canvasId is a *separate* field that uses
    # numeric canvas indexes — that is RAMP's own internal convention for its
    # <Transcript> component and cannot be changed without forking RAMP.
    if presenter.respond_to?(:canvas_index_for_member)
      index = presenter.canvas_index_for_member(member.id)
      return "#{manifest_urls[:default]}/canvas/#{member.id}" if index.present?
    end

    # Fallback for images not in the presenter's canvas index.
    if is_image
      image_members = presenter.original_item_members.select { |m| member_image?(m, member_label(m), member_mime_type(m)) }
      return "#{manifest_urls[:default]}/canvas/#{member.id}" if image_members.any? { |m| m.id.to_s == member.id.to_s }
    end

    nil
  end

  def manifest_displayable_member?(member)
    return false if representative_thumbnail_member?(member)

    return true unless presenter.respond_to?(:canvas_index_for_member)

    presenter.canvas_index_for_member(member.id).present?
  end

  def representative_av?
    representative = presenter.representative_presenter
    representative&.video? || representative&.audio?
  end

  def pdf_viewer_file_id
    @pdf_viewer_file_id ||= view_context.pdf_viewer_file_id_for_work(presenter)
  end

  def ramp_viewer_payload
    {
      type: VIEWER_TYPE_RAMP,
      manifestUrl: manifest_urls[:default],
      transcriptFiles: presenter.transcript_files
    }
  end

  def pdf_or_images_viewer_payload(pdf_id)
    {
      type: VIEWER_TYPE_PDF_OR_IMAGES,
      hasImages: view_context.has_images_for_work?(presenter),
      defaultViewer: view_context.default_viewer_for_work(presenter),
      pdfUrl: view_context.pdf_download_url_for_file(pdf_id),
      hocrUrl: view_context.hocr_download_url_for_work(presenter, pdf_file_id: pdf_id),
      manifestUrl: manifest_urls[:default]
    }
  end

  def clover_viewer_payload
    {
      type: VIEWER_TYPE_CLOVER,
      manifestUrl: manifest_urls[:default]
    }
  end

  def manifest_urls
    @manifest_urls ||= {
      default: view_context.manifest_url_for_work(presenter)
    }
  end

  def member_label(member)
    label = member.title.to_a.first.to_s
    label = member.label.to_s if label.blank? && member.respond_to?(:label)
    label
  end

  def member_mime_type(member)
    return member.mime_type.to_s.downcase if member.respond_to?(:mime_type)

    ''
  end

  def member_audio_video?(member, mime_type)
    return true if member.respond_to?(:audio?) && member.audio?
    return true if member.respond_to?(:video?) && member.video?
    return true if AV_EXTENSIONS.any? { |extension| member_label(member).to_s.downcase.end_with?(extension) }

    mime_type.start_with?('audio/', 'video/')
  end

  def member_pdf?(member, label, mime_type)
    return true if member.respond_to?(:pdf?) && member.pdf?
    return true if mime_type == 'application/pdf'

    label.to_s.downcase.end_with?('.pdf')
  end

  def member_image?(member, label, mime_type)
    return true if member.respond_to?(:image?) && member.image?
    return true if mime_type.start_with?('image/')

    downcased_label = label.to_s.downcase
    IMAGE_EXTENSIONS.any? { |extension| downcased_label.end_with?(extension) }
  end

  def representative_thumbnail_member?(member)
    return false unless presenter.respond_to?(:thumbnail_id)
    return false if presenter.thumbnail_id.blank?
    return false unless member.id.to_s == presenter.thumbnail_id.to_s

    related_url_candidates(member).any? do |value|
      value == 'derivative_type:thumbnail' || value.start_with?('representative_thumbnail_for_work:')
    end
  end

  def related_url_candidates(member)
    source = member.respond_to?(:model) ? member.model : member
    candidates = []
    candidates.concat(Array(source.related_url)) if source.respond_to?(:related_url)

    if member.respond_to?(:solr_document)
      candidates.concat(Array(member.solr_document['related_url_tesim']))
    end

    candidates.map(&:to_s)
  end
end
