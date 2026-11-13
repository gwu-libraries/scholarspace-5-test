# frozen_string_literal: true

class DerivativeJobs::WorkLevel::ReadingModePdfGeneration::FromImagesGenerateJob < ApplicationJob
  include JobDistributedLock
  include LockRetryProfiles::LongRunningShortBackoff

  queue_as :derivatives_reading_mode_pdf_generation_from_images_generate

  def perform(work_id:)
    Rails.logger.info(
      "derivative_pipeline event=image_pdf_from_images_generate_start work_id=#{work_id} " \
      "job_id=#{job_id} queue=#{queue_name}"
    )

    with_work(work_id: work_id) do |work|
      payload = Derivatives::WorkLevel::ReadingModePdfGeneration::FromImages.new(work).generate_to_cache(
        source_image_file_sets: Derivatives::FileSetLevel::TextExtraction::FromImages.new(work).source_image_file_sets
      )
      raise "Reading-mode PDF generation returned no payload for work=#{work.id}" unless payload

      DerivativeJobs::WorkLevel::ReadingModePdfGeneration::FromImagesPersistJob.perform_later(
        work_id: work.id.to_s,
        source_file_set_id: payload.fetch(:source_file_set_id),
        cache_file_identifier: payload.fetch(:cache_file_identifier),
        cache_filename: payload.fetch(:cache_filename)
      )
      Rails.logger.info(
        "derivative_pipeline event=image_pdf_from_images_generate_done work_id=#{work_id} " \
        "cache_file_identifier=#{payload.fetch(:cache_file_identifier)}"
      )
    end
  end

  protected

  def lock_key_for(arguments)
    "derivatives:reading_mode_pdf_generation:work:#{arguments[:work_id]}:from_images_generate"
  end
end