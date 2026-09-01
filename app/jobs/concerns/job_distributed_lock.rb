# frozen_string_literal: true

module JobDistributedLock
  extend ActiveSupport::Concern

  class LockUnavailableError < RuntimeError; end

  DEFAULT_LOCK_TIMEOUT_SECONDS = DerivativeJobSettings.seconds(:distributed_lock, :default_timeout_seconds)
  DEFAULT_LOCK_RETRY_COUNT = DerivativeJobSettings.seconds(:distributed_lock, :retry_count)
  DEFAULT_LOCK_RETRY_DELAY_MS = DerivativeJobSettings.seconds(:distributed_lock, :retry_delay_ms)
  DEFAULT_LOCK_RETRY_JITTER_MS = DerivativeJobSettings.seconds(:distributed_lock, :retry_jitter_ms)

  included do
    around_perform do |job, block|
      lock_key = job.lock_key_for(job.send(:normalized_lock_arguments))
      
      if lock_key
        timeout_seconds = job.send(:lock_timeout_seconds)
        job.send(:with_distributed_lock, lock_key, timeout_seconds, &block)
      else
        block.call
      end
    end
  end

  protected

  # Override to define lock strategy. Return nil to skip locking.
  def lock_key_for(_arguments)
    nil
  end

  # Override to customize lock timeout per job class
  def lock_timeout_seconds
    self.class.const_defined?(:LOCK_TIMEOUT_SECONDS) ? self.class::LOCK_TIMEOUT_SECONDS : DEFAULT_LOCK_TIMEOUT_SECONDS
  end

  private

  def normalized_lock_arguments
    return {} if arguments.empty?

    return arguments.first.with_indifferent_access if arguments.length == 1 && arguments.first.is_a?(Hash)

    arguments
  end

  def with_distributed_lock(lock_key, timeout_seconds)
    # Convert seconds to milliseconds for Redlock
    timeout_ms = timeout_seconds * 1000
    retry_count = ENV.fetch('DISTRIBUTED_LOCK_RETRY_COUNT', DEFAULT_LOCK_RETRY_COUNT).to_i
    retry_delay_ms = ENV.fetch('DISTRIBUTED_LOCK_RETRY_DELAY_MS', DEFAULT_LOCK_RETRY_DELAY_MS).to_i
    retry_jitter_ms = ENV.fetch('DISTRIBUTED_LOCK_RETRY_JITTER_MS', DEFAULT_LOCK_RETRY_JITTER_MS).to_i
    
    # Get Redis connection from Sidekiq
    redis_connection = Sidekiq.redis { |r| r }
    redlock_client = Redlock::Client.new([redis_connection])
    
    # Try to acquire lock with a short bounded retry window to reduce contention churn.
    lock_info = redlock_client.lock(
      lock_key,
      timeout_ms,
      retry_count: retry_count,
      retry_delay: retry_delay_ms,
      retry_jitter: retry_jitter_ms
    )
    
    unless lock_info
      Rails.logger.warn(
        "lock_unavailable key=#{lock_key} job_class=#{self.class.name} " \
        "job_id=#{job_id} queue=#{queue_name} timeout_seconds=#{timeout_seconds}"
      )
      raise LockUnavailableError, "Could not acquire lock for key=#{lock_key}; job will be retried"
    end

    Rails.logger.info("lock_acquired key=#{lock_key}")
    
    begin
      yield
    ensure
      redlock_client.unlock(lock_info)
      Rails.logger.info("lock_released key=#{lock_key}")
    end
  end
end
