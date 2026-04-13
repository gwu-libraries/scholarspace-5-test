module WorkViewerHelper
  # determines the default viewer tab for a work based on its file set members.
  # returns 'images' when unprocessed source images are present, otherwise 'pdf'.
  def default_viewer_for_work(presenter)
    has_source_image_files?(presenter) ? 'images' : 'pdf'
  end

  def pdf_viewer_file_id_for_work(presenter)
    preferred_rendering_pdf_file_set_id_for_work(presenter) ||
      pdf_presenter_for_work(presenter)&.id ||
      pdf_file_set_id_for_work(presenter)
  end

  def manifest_url_for_work(presenter)
    main_app.polymorphic_url([:manifest, presenter], locale: nil)
  end

  def pdf_download_url_for_file(file_id)
    download_path(id: file_id, locale: nil)
  end

  private

  def pdf_presenter_for_work(presenter)
    representative = presenter.representative_presenter
    return representative if representative&.respond_to?(:pdf?) && representative.pdf?

    member_presenters = Array(presenter.member_presenters)
    member_presenters.find { |member| member.respond_to?(:pdf?) && member.pdf? }
  end

  def pdf_file_set_id_for_work(presenter)
    Array(presenter.member_ids).each do |member_id|
      file_set = find_member_file_set(member_id)
      return file_set.id.to_s if file_set && pdf_file_set?(file_set)
    end
    nil
  end

  def preferred_rendering_pdf_file_set_id_for_work(presenter)
    Array(presenter.member_ids).each do |member_id|
      file_set = find_member_file_set(member_id)
      next unless file_set

      filename = file_set.original_file&.original_filename.to_s
      return file_set.id.to_s if filename.downcase.end_with?('_ocr_rendering.pdf')
    end
    nil
  end

  def has_source_image_files?(presenter)
    presenter.member_ids.filter_map { |id| find_member_file_set(id) }.any? do |file_set|
      next false unless file_set.original_file&.mime_type.to_s.start_with?('image/')

      !file_set.service_file
    end
  end

  def find_member_file_set(member_id)
    Hyrax.query_service.find_by(id: member_id)
  end

  def pdf_file_set?(file_set)
    mime_type = file_set.original_file&.mime_type.to_s
    filename = file_set.original_file&.original_filename.to_s
    mime_type == 'application/pdf' || filename.downcase.end_with?('.pdf')
  end
end
