# frozen_string_literal: true

class DerivativeJobs::WorkLevel::ReindexJob < ApplicationJob
  queue_as :derivatives_persist

  DEBOUNCE_KEY_PREFIX = 'derivatives:work_reindex:scheduled:'
  DEBOUNCE_SECONDS = DerivativeJobSettings.seconds(:waits, :work_reindex_debounce_seconds)

  def self.schedule(work_id:)
    key = "#{DEBOUNCE_KEY_PREFIX}#{work_id}"
    scheduled = Sidekiq.redis { |redis| redis.set(key, 1, nx: true, ex: DEBOUNCE_SECONDS) }
    set(wait: DEBOUNCE_SECONDS.seconds).perform_later(work_id: work_id) if scheduled
  end

  def perform(work_id:)
    with_work(work_id: work_id) do |work|
      Hyrax.index_adapter.save(resource: work)
    end
  ensure
    Sidekiq.redis { |redis| redis.del("#{DEBOUNCE_KEY_PREFIX}#{work_id}") }
  end
end
