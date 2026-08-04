# frozen_string_literal: true

class DerivativeJobs::WorkLevel::RepresentativeThumbnail::GenerateJob < ApplicationJob
  include JobDistributedLock
  include LockRetryProfiles::ShortBackoff

  queue_as :derivatives_representative_thumbnail_generate

  def perform(work_id:)
    with_work(work_id: work_id) do |work|
      payload = Derivatives::WorkLevel::RepresentativeThumbnail.new(work).generate_payload
      next unless payload

      DerivativeJobs::WorkLevel::RepresentativeThumbnail::PersistJob.perform_later(
        work_id: work.id.to_s,
        source_file_set_id: payload.fetch(:source_file_set_id)
      )
    end
  end

  protected

  def lock_key_for(arguments)
    "derivatives:representative_thumbnail:work:#{arguments[:work_id]}:generate"
  end
end
