# frozen_string_literal: true

class DerivativeJobs::WorkLevel::RepresentativeThumbnail::GenerateJob < ApplicationJob
  include JobDistributedLock
  include LockRetryProfiles::ShortBackoff

  queue_as :derivatives_representative_thumbnail_generate

  def perform(work_id:)
    with_work(work_id: work_id) do |work|
      payload = Derivatives::WorkLevel::RepresentativeThumbnail::FromSourceFileSet.new(work).generate_to_cache
      raise "Representative thumbnail generation returned no payload for work=#{work.id}" unless payload

      DerivativeJobs::WorkLevel::RepresentativeThumbnail::PersistJob.perform_later(
        work_id: work.id.to_s,
        source_file_set_id: payload.fetch(:source_file_set_id),
        cache_file_identifier: payload.fetch(:cache_file_identifier),
        cache_filename: payload.fetch(:cache_filename)
      )
    end
  end

  protected

  def lock_key_for(arguments)
    "derivatives:representative_thumbnail:work:#{arguments[:work_id]}:generate"
  end
end
