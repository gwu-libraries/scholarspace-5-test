# frozen_string_literal: true

module LockRetryProfiles
  # Backoff values aligned with ApplicationJobRetryPolicy defaults.
  # Include this in jobs that should keep the standard lock retry behavior.
  module DefaultBackoff
    LOCK_RETRY_ATTEMPTS = 30
    LOCK_RETRY_MAX_WAIT_SECONDS = 20
    LOCK_RETRY_JITTER_SECONDS = 2
  end

  # Short, frequent retries intended for lock-contention-prone persist/finalize
  # jobs so they stay in ActiveJob retry policy instead of quickly spilling into
  # Sidekiq's longer exponential retry schedule.
  module ShortBackoff
    LOCK_RETRY_ATTEMPTS = 360
    LOCK_RETRY_MAX_WAIT_SECONDS = 10
    LOCK_RETRY_JITTER_SECONDS = 1
  end
end
