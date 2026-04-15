module WorkViewerHelper
  # determines the default viewer tab for a work based on its file set members.
  def default_viewer_for_work(presenter)
    has_source_image_files?(presenter) ? 'images' : 'pdf'
  end

  def pdf_viewer_file_id_for_work(presenter)
    pdf_presenter_for_work(presenter)&.id ||
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
    Array(presenter.member_ids).each do |member_id|
      file_set = find_member_file_set(member_id)
      return file_set.id.to_s if file_set && pdf_file_set?(file_set)
    end
    nil
  end

  def hocr_file_set_id_for_pdf(presenter, pdf_file_id)
    return nil if pdf_file_id.blank?

    pdf_file_set = find_member_file_set(pdf_file_id)
    return nil unless pdf_file_set

    expected_name = expected_hocr_filename_for_pdf_file_set(pdf_file_set)
    member_file_sets = Array(presenter.member_ids).filter_map { |id| find_member_file_set(id) }

    if expected_name.present?
      exact_match = member_file_sets.find do |file_set|
        filename = file_set.original_file&.original_filename.to_s
        filename.casecmp(expected_name).zero?
      end
      return exact_match.id.to_s if exact_match
    end

    fallback = member_file_sets.find do |file_set|
      filename = file_set.original_file&.original_filename.to_s
      filename.downcase.end_with?('.hocr')
    end
    fallback&.id&.to_s
  end

  def expected_hocr_filename_for_pdf_file_set(pdf_file_set)
    filename = pdf_file_set.original_file&.original_filename.to_s
    return nil if filename.blank?

    "#{File.basename(filename, File.extname(filename))}_HOCR.hocr"
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
