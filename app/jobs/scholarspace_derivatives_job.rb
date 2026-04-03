# frozen_string_literal: true

require 'fileutils'

class ScholarspaceDerivativesJob < ApplicationJob
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

  def member_file_sets
    Array(@work.member_ids).filter_map { |id| find_member_file_set(id) }
  end
  
  def original_member_file_sets
    member_file_sets.reject(&:service_file)
  end

  def file_types
    original_member_file_sets.filter_map { |file_set| file_set.original_file&.mime_type }.uniq
  end

  # check if every file in the work has been characterized
  def files_ready_for_derivatives?
    original_member_file_sets.all? { |file_set| file_set.original_file&.mime_type.present? }
  end

  def schedule_derivatives_jobs
    unless files_ready_for_derivatives?
      reschedule_job
      return
    end

    ThumbnailDerivativesJob.perform_later(work_id: @work.id.to_s) if file_types.any? { |ft| ft.start_with?('image/') || ft == 'application/pdf' }
    PdfToImagesDerivativesJob.perform_later(work_id: @work.id.to_s) if file_types.include?('application/pdf')
    ImagesToPdfDerivativesJob.perform_later(work_id: @work.id.to_s) if file_types.any? { |ft| ft.start_with?('image/') }
    AudioTranscriptDerivativesJob.perform_later(work_id: @work.id.to_s) if file_types.any? { |ft| ft.start_with?('audio/', 'video/') }
  end

  def reschedule_job
    return if @retries > RETRY_MAX

    # incrementally increase the amount of time waiting before retrying
    ScholarspaceDerivativesJob.set(wait: @retries.minutes).perform_later(
      work_id: @work_id,
      retries: @retries
    )
  end

  def find_member_file_set(id)
    Hyrax.query_service.find_by(id: id)
  end

  def with_work_lock(work_id)
    lock_root = Rails.root.join('tmp', 'derivatives-work-locks').to_s
    FileUtils.mkdir_p(lock_root)
    lock_path = File.join(lock_root, "#{work_id}.lock")

    File.open(lock_path, File::RDWR | File::CREAT, 0o644) do |lock_file|
      lock_file.flock(File::LOCK_EX)
      yield
    ensure
      lock_file.flock(File::LOCK_UN)
    end
  end
end
