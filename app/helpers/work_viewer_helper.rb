module WorkViewerHelper
  include ::FileSetDerivativeMetadata

  # determines the default viewer tab for a work based on its file set members.
  def default_viewer_for_work(presenter)
    has_source_image_files?(presenter) ? 'images' : 'pdf'
  end

  def has_images_for_work?(presenter)
    has_source_image_files?(presenter)
  end

  def pdf_viewer_file_id_for_work(presenter)
    pdf_file_set_id_for_work(presenter)
  end

  def manifest_url_for_work(presenter)
    main_app.polymorphic_url([:manifest, presenter], locale: nil)
  end

  def pdf_download_url_for_file(file_id)
    download_path(id: file_id, locale: nil)
  end

  def hocr_download_url_for_work(presenter, pdf_file_id: nil)
    pdf_file_id ||= pdf_viewer_file_id_for_work(presenter)
    hocr_file_id = hocr_file_set_id_for_pdf(presenter, pdf_file_id)
    return nil if hocr_file_id.blank?

    download_path(id: hocr_file_id, locale: nil)
  end

  private

  def pdf_presenter_for_work(presenter)
    representative = presenter.representative_presenter
    return representative if representative&.respond_to?(:pdf?) && representative.pdf?

    member_presenters = Array(presenter.member_presenters)
    member_presenters.find { |member| member.respond_to?(:pdf?) && member.pdf? }
  end

  def pdf_file_set_id_for_work(presenter)
    all_pdf_file_sets = member_file_sets_for(presenter).select { |file_set| file_set && pdf_file_set?(file_set) }
    joined = all_pdf_file_sets.find { |file_set| file_set_filename(file_set) == ScholarspaceDerivativesServices::ImagesToPdfDerivativesService::JOINED_PDF_FILENAME }
    joined ||= all_pdf_file_sets.first
    joined&.id&.to_s
  end

  def hocr_file_set_id_for_pdf(presenter, pdf_file_id)
    return nil if pdf_file_id.blank?

    pdf_file_set = find_member_file_set(pdf_file_id)
    return nil unless pdf_file_set

    joined_hocr_id = joined_pdf_hocr_file_set_id(presenter, pdf_file_set)
    return joined_hocr_id if joined_hocr_id.present?

    metadata_linked_hocr_file_set_id(presenter, pdf_file_set)
  end

  def joined_pdf_hocr_file_set_id(presenter, pdf_file_set)
    return nil unless joined_pdf_file_set?(pdf_file_set)

    joined_hocr_filename = ScholarspaceDerivativesServices::ImagesToPdfDerivativesService::JOINED_PDF_FILENAME
                             .sub('.pdf', '_HOCR.hocr')
    match = member_file_sets_for(presenter).find do |file_set|
      hocr_file_set?(file_set) && file_set_filename(file_set) == joined_hocr_filename
    end
    match&.id&.to_s
  end

  def metadata_linked_hocr_file_set_id(presenter, pdf_file_set)
    metadata_match = member_file_sets_for(presenter).find do |file_set|
      source_file_set_id_tag_for(file_set) == pdf_file_set.id.to_s && hocr_file_set?(file_set)
    end
    metadata_match&.id&.to_s
  end

  def joined_pdf_file_set?(file_set)
    file_set_filename(file_set) == ScholarspaceDerivativesServices::ImagesToPdfDerivativesService::JOINED_PDF_FILENAME
  end

  def has_source_image_files?(presenter)
    member_file_sets_for(presenter).any? do |file_set|
      next false unless file_set.original_file&.mime_type.to_s.start_with?('image/')

      !file_set.service_file
    end
  end

  def member_file_sets_for(presenter)
    @member_file_sets_by_presenter ||= {}
    @member_file_sets_by_presenter[presenter.id.to_s] ||= Array(presenter.member_ids).filter_map do |member_id|
      find_member_file_set(member_id)
    end
  end

  def find_member_file_set(member_id)
    @member_file_set_by_id ||= {}
    key = member_id.to_s
    @member_file_set_by_id[key] ||= Hyrax.query_service.find_by(id: member_id)
  end

  def pdf_file_set?(file_set)
    file_set.pdf?
  end

  def hocr_file_set?(file_set)
    file_set.hocr?
  end

  def file_set_filename(file_set)
    file_set.file_display_name
  end
end
