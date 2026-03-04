# frozen_string_literal: true

class CreateCustomDerivativesJob < ApplicationJob
  # This job is for generating any derivatives that are needed for additional functionality not included in base Hyrax
  # For example, if we want a work that has a collection of images attached to generated a PDF for display,
  # or a PDF deposited that should be split into component images for RIIIF rendering

  # For simplicity sake, we are waiting until all of the filesets attach to a work have been characterized prior to
  # generating any of these custom derivatives - as some require processing files from multiple filesets.

  # How many times should this process retry?
  RETRY_MAX = 10

  def perform(work_id:, retries: 0)
    @work_id = work_id
    @work = Hyrax.query_service.find_by(id: @work_id)
    @retries = retries + 1

    begin
      identify_file_types
      create_derivatives
    rescue StandardError
      reschedule_job
    end
  end

  def file_types
    member_file_sets = @work.member_ids.map { |id| Hyrax.query_service.find_by(id: id) }
    member_file_sets.map { |fs| fs.original_file.mime_type }.uniq
  end

  def create_derivatives
    reschedule_job if file_types.any? { |ft| ft.empty? }

    if file_types.any? { |ft| ft.start_with?('audio/', 'video/') }
      CustomDerivativesServices::AudioTranscriptDerivativesService.new(@work).call
    end

    return unless file_types.any? { |ft| ft.start_with?('image/') }

    CustomDerivativesServices::ImagesToPdfDerivativesService.new(@work).call

    # CustomDerivativesServices::PdfToImagesDerivativesService.new(@work).create_derivates
    # raise StandardError, 'Not implemented yet'
  end

  def reschedule_job
    return if @retries > RETRY_MAX

    # incrementally increase the amount of time waiting before retrying
    CreateCustomDerivativesJob.set(wait: @retries.minutes).perform_later(
      work_id: @work_id,
      retries: @retries
    )
  end
end
