# frozen_string_literal: true

module ApplicationJobRetryPolicy
  extend ActiveSupport::Concern

  DEFAULT_MAX_RETRY_WAIT_SECONDS = DerivativeJobSettings.seconds(:retry_policy, :default_max_wait_seconds)
  DEFAULT_ERROR_RETRY_ATTEMPTS_COUNT = DerivativeJobSettings.seconds(:retry_policy, :default_error_attempts)
  NO_METHOD_ERROR_RETRY_ATTEMPTS = DerivativeJobSettings.seconds(:retry_policy, :no_method_error_attempts)
  DEFAULT_ERROR_RETRY_ATTEMPTS = {
    NoMethodError => NO_METHOD_ERROR_RETRY_ATTEMPTS,
    RuntimeError => DEFAULT_ERROR_RETRY_ATTEMPTS_COUNT,
    Valkyrie::StorageAdapter::FileNotFound => DEFAULT_ERROR_RETRY_ATTEMPTS_COUNT,
    Valkyrie::Persistence::ObjectNotFoundError => DEFAULT_ERROR_RETRY_ATTEMPTS_COUNT,
    Valkyrie::Persistence::StaleObjectError => DEFAULT_ERROR_RETRY_ATTEMPTS_COUNT,
    **(defined?(::Ldp::Conflict) ? { ::Ldp::Conflict => DEFAULT_ERROR_RETRY_ATTEMPTS_COUNT } : {}),
    **(defined?(::Ldp::HttpError) ? { ::Ldp::HttpError => DEFAULT_ERROR_RETRY_ATTEMPTS_COUNT } : {})
  }.freeze

  included do
    rescue_from(StandardError) do |error|
      attempts = configured_retry_attempts_for(error)
      raise error if attempts.nil?
      raise error if attempts <= 0

      # ActiveJob counts the current run in `executions`.
      if executions < attempts
        wait_seconds = configured_retry_wait_seconds_for(error)
        Rails.logger.warn(retry_log_message(error: error, attempts: attempts, wait_seconds: wait_seconds))
        retry_job wait: wait_seconds.seconds, error: error
        next
      end

      raise error
    end
  end

  protected

  def retry_policy_max_wait_seconds
    self.class.const_defined?(:MAX_RETRY_WAIT_SECONDS) ? self.class::MAX_RETRY_WAIT_SECONDS : DEFAULT_MAX_RETRY_WAIT_SECONDS
  end

  def retry_policy_attempts
    self.class.const_defined?(:ERROR_RETRY_ATTEMPTS) ? self.class::ERROR_RETRY_ATTEMPTS : DEFAULT_ERROR_RETRY_ATTEMPTS
  end

  def lock_retry_attempts
    lock_retry_policy_value(:LOCK_RETRY_ATTEMPTS)
  end

  def lock_retry_max_wait_seconds
    lock_retry_policy_value(:LOCK_RETRY_MAX_WAIT_SECONDS)
  end

  def lock_retry_jitter_seconds
    lock_retry_policy_value(:LOCK_RETRY_JITTER_SECONDS)
  end

  def lock_retry_policy_value(const_name)
    if self.class.const_defined?(const_name)
      self.class.const_get(const_name)
    else
      LockRetryProfiles::DefaultBackoff.const_get(const_name)
    end
  end

  def configured_retry_attempts_for(error)
    return lock_retry_attempts if lock_contention_error?(error)

    matching_classes = retry_policy_attempts.keys.select { |klass| error.is_a?(klass) }
    return nil if matching_classes.empty?

    # Prefer the closest ancestor match so specific classes win over broad
    # fallbacks (for example Ldp::HttpError over RuntimeError).
    error_ancestors = error.class.ancestors
    error_class = matching_classes.min_by { |klass| error_ancestors.index(klass) || Float::INFINITY }
    return nil unless error_class

    retry_policy_attempts[error_class].to_i
  end

  def configured_retry_wait_seconds_for(error)
    return lock_retry_wait_seconds if lock_contention_error?(error)

    [2**executions, retry_policy_max_wait_seconds].min
  end

  def lock_retry_wait_seconds
    base_wait = [executions + 1, lock_retry_max_wait_seconds].min
    base_wait + rand(0..lock_retry_jitter_seconds)
  end

  def lock_contention_error?(error)
    error.class.name == 'JobDistributedLock::LockUnavailableError'
  end

  def retry_log_message(error:, attempts:, wait_seconds:)
    context = retry_context_for_error(error: error, attempts: attempts, wait_seconds: wait_seconds)
    "job_retry_scheduled #{context.map { |key, value| "#{key}=#{value}" }.join(' ')}"
  end

  def retry_context_for_error(error:, attempts:, wait_seconds:)
    {
      job_class: self.class.name,
      queue: queue_name.to_s,
      job_id: job_id.to_s,
      lock_contention: lock_contention_error?(error),
      executions: executions.to_i,
      max_attempts: attempts.to_i,
      wait_seconds: wait_seconds.to_i,
      error_class: error.class.name,
      work_id: retry_context_work_id
    }.compact
  end

  def retry_context_work_id
    return nil if arguments.blank?

    args = arguments.first
    return nil unless args.is_a?(Hash)

    args.with_indifferent_access[:work_id]&.to_s
  end

  # Re-enqueue a job with explicit retry state and backoff delay.
  # Returns false when retries have exceeded the max; true when re-enqueued.
  def reschedule_with_retry(job_class:, args:, retries:, retry_max:, wait_seconds:)
    return false if retries > retry_max

    job_class
      .set(wait: wait_seconds.seconds)
      .perform_later(**args, retries: retries)

    true
  end

  # Linear retry backoff helper.
  def linear_retry_wait_seconds(retries:, step_seconds: 60, max_seconds: retry_policy_max_wait_seconds)
    [retries * step_seconds, max_seconds].min
  end
end
