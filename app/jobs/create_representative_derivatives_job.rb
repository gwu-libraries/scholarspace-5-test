# frozen_string_literal: true

class CreateRepresentativeDerivativesJob < ApplicationJob
  # This job is for generating any derivatives that are needed for additional display functionality.
  # For example, if we want a work that has a collection of images attached to generated a PDF for display,
  # or a PDF deposited that should be split into component images for RIIIF rendering

  # How many times should this process retry?
  RETRY_MAX = 10

  def perform(work_id:, retries: 0)
    @work_id = work_id
    @work = Hyrax.query_service.find_by(id: @work_id)
    @retries = retries + 1

    begin
      create_derivatives
    rescue StandardError
      reschedule_job
    end
  end

  def create_derivatives
    DerivativesServices::WorkImagesToPdfDerivativesService.new(@work).create_derivatives
    # raise StandardError, 'Not implemented yet'
  end

  def reschedule_job
    return if @retries > RETRY_MAX

    # incrementally increase the amount of time waiting before retrying
    CreateRepresentativeDerivativesJob.set(wait: @retries.minutes).perform_later(
      work_id: @work_id,
      retries: @retries
    )
  end
end
