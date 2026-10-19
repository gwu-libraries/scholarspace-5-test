# frozen_string_literal: true

module WorkViewerHelper
  def default_viewer_for_work(presenter)
    has_images_for_work?(presenter) ? 'images' : 'pdf'
  end

  def has_images_for_work?(presenter)
    work_viewer_resolver_for(presenter).images?
  end

  def pdf_viewer_file_id_for_work(presenter)
    work_viewer_resolver_for(presenter).pdf_file_id
  end

  def manifest_url_for_work(presenter)
    main_app.polymorphic_url([:manifest, presenter], locale: nil)
  end

  def ramp_manifest_url_for_work(presenter)
    manifest_url_for_work(presenter).sub(/\?.*\z/, '') + '?viewer=ramp'
  end

  def clover_manifest_url_for_work(presenter)
    manifest_url_for_work(presenter).sub(/\?.*\z/, '') + '?viewer=clover'
  end

  def pdf_download_url_for_file(file_id)
    Hyrax::Engine.routes.url_helpers.download_path(id: file_id, locale: nil)
  end

  def preferred_download_url_for_member(presenter, member_id)
    member = work_viewer_resolver_for(presenter).preferred_download_member(member_id)
    Hyrax::Engine.routes.url_helpers.download_path(id: member.id, locale: nil) if member
  end

  def hocr_download_url_for_work(presenter, pdf_file_id: nil)
    pdf_file_id ||= pdf_viewer_file_id_for_work(presenter)
    hocr_file_id = work_viewer_resolver_for(presenter).hocr_file_id(pdf_file_id)
    return nil if hocr_file_id.blank?

    Hyrax::Engine.routes.url_helpers.download_path(id: hocr_file_id, locale: nil)
  end

  private

  def work_viewer_resolver_for(presenter)
    @work_viewer_resolvers ||= {}
    @work_viewer_resolvers[presenter.id.to_s] ||= Resolvers::WorkViewerResolver.new(presenter: presenter)
  end
end
