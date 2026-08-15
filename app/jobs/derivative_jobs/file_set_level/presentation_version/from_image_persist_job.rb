# frozen_string_literal: true

class DerivativeJobs::FileSetLevel::PresentationVersion::FromImagePersistJob < ApplicationJob
  include JobDistributedLock
  include LockRetryProfiles::LongRunningShortBackoff

  queue_as :derivatives_presentation_version_from_image_persist

  def perform(work_id:, source_file_set_id:, cache_file_identifier:, cache_filename:)
    with_work(work_id: work_id) do |work|
      Derivatives::FileSetLevel::PresentationVersion::FromImage.new(work).persist_from_cache(
        source_file_set_id: source_file_set_id,
        cache_file_identifier: cache_file_identifier,
        cache_filename: cache_filename
      )
    end
  end

  protected

  def lock_key_for(arguments)
    "derivatives:presentation_version:image:work:#{arguments[:work_id]}:persist"
  end
end
