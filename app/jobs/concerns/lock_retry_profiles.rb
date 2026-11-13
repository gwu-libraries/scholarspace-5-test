# frozen_string_literal: true

module LockRetryProfiles
  # Backoff values aligned with ApplicationJobRetryPolicy defaults.
  # Include one or the other in jobs to set retry policy.

  module DefaultBackoff
    LOCK_RETRY_ATTEMPTS = DerivativeJobSettings.seconds(:lock_profiles, :default_backoff, :retry_attempts)
    LOCK_RETRY_MAX_WAIT_SECONDS = DerivativeJobSettings.seconds(:lock_profiles, :default_backoff, :retry_max_wait_seconds)
    LOCK_RETRY_JITTER_SECONDS = DerivativeJobSettings.seconds(:lock_profiles, :default_backoff, :retry_jitter_seconds)
  end

  # Short, frequent retries intended for lock-contention-prone persist/finalize
  # jobs so they stay in ActiveJob retry policy
  module ShortBackoff
    LOCK_TIMEOUT_SECONDS = DerivativeJobSettings.seconds(:lock_profiles, :short_backoff, :timeout_seconds)
    LOCK_RETRY_ATTEMPTS = DerivativeJobSettings.seconds(:lock_profiles, :short_backoff, :retry_attempts)
    LOCK_RETRY_MAX_WAIT_SECONDS = DerivativeJobSettings.seconds(:lock_profiles, :short_backoff, :retry_max_wait_seconds)
    LOCK_RETRY_JITTER_SECONDS = DerivativeJobSettings.seconds(:lock_profiles, :short_backoff, :retry_jitter_seconds)
  end

  module LongRunningShortBackoff
    LOCK_TIMEOUT_SECONDS = DerivativeJobSettings.seconds(:lock_profiles, :long_running_short_backoff, :timeout_seconds)
    LOCK_RETRY_ATTEMPTS = ShortBackoff::LOCK_RETRY_ATTEMPTS
    LOCK_RETRY_MAX_WAIT_SECONDS = ShortBackoff::LOCK_RETRY_MAX_WAIT_SECONDS
    LOCK_RETRY_JITTER_SECONDS = ShortBackoff::LOCK_RETRY_JITTER_SECONDS
  end
end
