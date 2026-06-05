# frozen_string_literal: true

require 'fileutils'

class DerivativesJob < ApplicationJob
  include FileOperations
  include PersistenceAdapter
  # For simplicity sake, we are waiting until all of the filesets attach to a work have been characterized prior to
  # generating any of these scholarspace derivatives - as some require processing files from multiple filesets.

  # How many times should this process retry?
  RETRY_MAX = 10

  def perform(work_id:, retries: 0)
    @work_id = work_id
    @retries = retries + 1

    with_work_lock(@work_id) do
      @work = Hyrax.query_service.find_by(id: @work_id)
      return unless @work

      schedule_derivatives_jobs
    end
  end

  def file_types
    @work.original_member_file_sets.filter_map { |file_set| file_set.original_file&.mime_type }.uniq
  end

  def has_pdf_source_files?
    @work.original_member_file_sets.any?(&:pdf?)
  end

  def has_image_source_files?
    @work.original_member_file_sets.any?(&:image?)
  end

  # check if every file in the work has been characterized
  def files_ready_for_derivatives?
    @work.original_member_file_sets.all? { |file_set| file_set.original_file&.mime_type.present? }
  end

  def schedule_derivatives_jobs
    unless files_ready_for_derivatives?
      reschedule_job
      return
    end

    ensure_default_representative_selection

    # generate a thumbnail
    ThumbnailDerivativesJob.perform_later(work_id: @work.id.to_s) if file_types.any? { |ft| ft.start_with?('image/', 'video/') } || has_pdf_source_files?

    #  we're not using this PdfToImagesJob for the time being since it's not working well with our current pdfs and we don't have a pressing need for it, but we can revisit in the future if we want to generate images from pdfs for any reason

    # PdfToImagesDerivativesJob.perform_later(work_id: @work.id.to_s) if file_types.include?('application/pdf')

    # if a collection of images, generate a pdf
    if has_image_source_files?
      ImagesToPdfDerivativesJob.perform_later(work_id: @work.id.to_s)
    end

    # if a/v, generate a transcript
    AudioTranscriptDerivativesJob.perform_later(work_id: @work.id.to_s) if file_types.any? { |ft| ft.start_with?('audio/', 'video/') }

    # if a pdf, extract text for full text search and OCR highlighting
    # This is ALWAYS done regardless of preferences
    PdfTextExtractionJob.perform_later(work_id: @work.id.to_s) if has_pdf_source_files?
  end



  def reschedule_job
    return if @retries > RETRY_MAX

    # incrementally increase the amount of time waiting before retrying
    DerivativesJob.set(wait: @retries.minutes).perform_later(
      work_id: @work_id,
      retries: @retries
    )
  end

  def ensure_default_representative_selection
    return unless @work.respond_to?(:representative_id=)

    preferred_source = preferred_representative_source_file_set
    return unless preferred_source

    preferred_id = preferred_source.id.to_s
    return if @work.representative_id.to_s == preferred_id

    @work.representative_id = preferred_source.id
    @work = save_and_index(@work)
  end

  def preferred_representative_source_file_set
    Array(@work.original_member_file_sets)
      .select { |file_set| representative_priority_for(file_set) < 99 }
      .min_by { |file_set| [representative_priority_for(file_set), representative_sort_name_for(file_set)] }
  end

  def representative_priority_for(file_set)
    mime_type = file_set.original_file&.mime_type.to_s.downcase

    return 0 if av_source_file_set?(file_set, mime_type)
    return 1 if pdf_source_file_set?(file_set, mime_type)
    return 2 if image_source_file_set?(file_set, mime_type)

    99
  end

  def representative_sort_name_for(file_set)
    file_set.original_file&.original_filename.to_s.downcase
  end

  def av_source_file_set?(file_set, mime_type)
    (file_set.respond_to?(:audio?) && file_set.audio?) ||
      (file_set.respond_to?(:video?) && file_set.video?) ||
      mime_type.start_with?('audio/', 'video/')
  end

  def pdf_source_file_set?(file_set, mime_type)
    (file_set.respond_to?(:pdf?) && file_set.pdf?) || mime_type == 'application/pdf'
  end

  def image_source_file_set?(file_set, mime_type)
    (file_set.respond_to?(:image?) && file_set.image?) || mime_type.start_with?('image/')
  end

  def with_work_lock(work_id)
    lock_root = Rails.root.join('tmp', 'derivatives-work-locks').to_s
    ensure_directory_exists(lock_root)
    FileUtils.chmod(0o755, lock_root) unless File.stat(lock_root).mode & 0o755 == 0o755
    lock_path = File.join(lock_root, "#{work_id}.lock")

    File.open(lock_path, File::RDWR | File::CREAT, 0o666) do |lock_file|
      lock_file.flock(File::LOCK_EX)
      yield
    ensure
      lock_file.flock(File::LOCK_UN)
    end
  end
end
