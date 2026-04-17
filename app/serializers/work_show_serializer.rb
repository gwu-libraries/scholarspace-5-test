# frozen_string_literal: true

class WorkShowSerializer

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
    rep = presenter.representative_presenter
    is_av = rep&.video? || rep&.audio?
    is_pdf = !is_av && view_context.pdf_viewer_file_id_for_work(presenter).present?

    if is_av
      {
        type: 'ramp',
        manifestUrl: view_context.manifest_url_for_work(presenter),
        transcriptFiles: presenter.transcript_files
      }
    elsif is_pdf
      pdf_id = view_context.pdf_viewer_file_id_for_work(presenter)

      {
        type: 'pdf_or_images',
        hasImages: view_context.has_images_for_work?(presenter),
        defaultViewer: view_context.default_viewer_for_work(presenter),
        pdfUrl: view_context.pdf_download_url_for_file(pdf_id),
        hocrUrl: view_context.hocr_download_url_for_work(presenter, pdf_file_id: pdf_id),
        manifestUrl: view_context.manifest_url_for_work(presenter)
      }
    else
      {
        type: 'clover',
        manifestUrl: view_context.manifest_url_for_work(presenter)
      }
    end
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
      .map do |member|
      label = member.title.to_a.first.to_s
      label = member.label.to_s if label.blank? && member.respond_to?(:label)

      {
        id: member.id.to_s,
        label: label,
        dateUploaded: (member.respond_to?(:date_uploaded) ? Array(member.date_uploaded).first.to_s : ''),
        visibility: (member.respond_to?(:visibility) ? member.visibility.to_s : ''),
        showUrl: Rails.application.routes.url_helpers.hyrax_file_set_path(member.id),
        downloadUrl: Hyrax::Engine.routes.url_helpers.download_path(id: member.id, locale: nil),
        editUrl: (Rails.application.routes.url_helpers.edit_hyrax_file_set_path(member.id) if can_edit)
      }
      end
      .sort_by { |member| member[:label].to_s.downcase }
  end
end
