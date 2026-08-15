# frozen_string_literal: true

class DerivativeJobs::WorkLevel::ReadingModePdfGeneration::FromImagesPersistJob < ApplicationJob
  include JobDistributedLock
  include LockRetryProfiles::LongRunningShortBackoff

  queue_as :derivatives_reading_mode_pdf_generation_from_images_persist

  def perform(work_id:, source_file_set_id:, cache_file_identifier:, cache_filename:)
    Rails.logger.info(
      "derivative_pipeline event=image_pdf_from_images_persist_start work_id=#{work_id} " \
      "source_file_set_id=#{source_file_set_id} job_id=#{job_id} queue=#{queue_name}"
    )

    with_work(work_id: work_id) do |work|
      pdf_file_set_id = Derivatives::WorkLevel::ReadingModePdfGeneration::FromImages.new(work).persist_from_cache(
        source_file_set_id: source_file_set_id,
        cache_file_identifier: cache_file_identifier,
        cache_filename: cache_filename
      )
      Rails.logger.info(
        "derivative_pipeline event=image_pdf_from_images_persist_done work_id=#{work_id} " \
        "joined_pdf_file_set_id=#{pdf_file_set_id}"
      )
    end
  end

  protected

  def lock_key_for(arguments)
    source_file_set_id = arguments[:source_file_set_id].to_s
    "derivatives:reading_mode_pdf_generation:work:#{arguments[:work_id]}:source:#{source_file_set_id}:from_images_persist"
  end
end