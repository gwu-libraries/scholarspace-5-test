# frozen_string_literal: true

class DerivativeJobs::FileSetLevel::Thumbnail::PersistJob < ApplicationJob
  include JobDistributedLock
  include LockRetryProfiles::ShortBackoff

  queue_as :derivatives_thumbnail_persist

  def perform(work_id:, source_file_set_id:, cache_file_identifier:, cache_filename:)
    with_work(work_id: work_id) do |work|
      Derivatives::FileSetLevel::ThumbnailCreation::Thumbnail.new(work).persist_from_cache(
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
    "derivatives:thumbnail:work:#{arguments[:work_id]}:source:#{source_file_set_id}:persist"
  end

end
