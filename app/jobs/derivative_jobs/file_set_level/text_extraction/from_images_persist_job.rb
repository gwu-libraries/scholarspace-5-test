# frozen_string_literal: true

class DerivativeJobs::FileSetLevel::TextExtraction::FromImagesPersistJob < ApplicationJob
  include JobDistributedLock
  include LockRetryProfiles::ShortBackoff

  queue_as :derivatives_text_extraction_from_images_persist

  def perform(work_id:, source_file_set_id:, cache_file_identifier:, cache_filename:)
    Rails.logger.info(
      "derivative_pipeline event=image_text_persist_start work_id=#{work_id} " \
      "source_file_set_id=#{source_file_set_id} job_id=#{job_id} queue=#{queue_name}"
    )

    with_work(work_id: work_id) do |work|
      Derivatives::FileSetLevel::TextExtraction::FromImages.new(work).persist_from_cache(
        source_file_set_id: source_file_set_id,
        cache_file_identifier: cache_file_identifier,
        cache_filename: cache_filename
      )
    end

  end

  protected

  def lock_key_for(arguments)
    source_file_set_id = arguments[:source_file_set_id].to_s
    # Lock per source file set to avoid whole-work lock contention.
    "derivatives:text_extraction_from_images:work:#{arguments[:work_id]}:source:#{source_file_set_id}:persist"
  end

end
