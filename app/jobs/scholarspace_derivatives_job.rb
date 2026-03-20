# frozen_string_literal: true

class ScholarspaceDerivativesJob < ApplicationJob
  include ScholarspaceDerivativesServices::Concerns::DerivativeClassifiable

  # For simplicity sake, we are waiting until all of the filesets attach to a work have been characterized prior to
  # generating any of these scholarspace derivatives - as some require processing files from multiple filesets.

  # How many times should this process retry?
  RETRY_MAX = 10

  def perform(work_id:, retries: 0)
    @work_id = work_id
    @work = Hyrax.query_service.find_by(id: @work_id)
    return unless @work

    @retries = retries + 1

    schedule_derivatives_jobs
  end

  def file_types
    source_member_file_sets.filter_map { |file_set| file_set.original_file&.mime_type }.uniq
  end

  def member_file_sets
    @work.member_ids.filter_map { |id| Hyrax.query_service.find_by(id: id) }
  end

  def source_member_file_sets
    member_file_sets.reject { |file_set| derivative_generated_file_set?(file_set, parent_resource: @work) }
  end

  # check if every file in the work has been characterized
  def files_ready_for_derivatives?
    source_member_file_sets.all? { |file_set| file_set.original_file&.mime_type.present? }
  end

  def schedule_derivatives_jobs
    unless files_ready_for_derivatives?
      reschedule_job
      return
    end

    PdfToImagesDerivativesJob.perform_later(work_id: @work.id.to_s) if file_types.include?('application/pdf')
    ImagesToPdfDerivativesJob.perform_later(work_id: @work.id.to_s) if file_types.any? { |ft| ft.start_with?('image/') }
    AudioTranscriptDerivativesJob.perform_later(work_id: @work.id.to_s) if file_types.any? { |ft| ft.start_with?('audio/', 'video/') }
    ThumbnailDerivativesJob.perform_later(work_id: @work.id.to_s)
  end

  def reschedule_job
    return if @retries > RETRY_MAX

    # incrementally increase the amount of time waiting before retrying
    ScholarspaceDerivativesJob.set(wait: @retries.minutes).perform_later(
      work_id: @work_id,
      retries: @retries
    )
  end
end
