# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationJobRetryPolicy do
  subject(:job) { DerivativeJobs::WorkLevel::OrchestrateJob.new }

  describe '#configured_retry_attempts_for' do
    it 'includes Ldp::Conflict in default retry policy when available' do
      skip 'Ldp::Conflict is not available in this runtime' unless defined?(::Ldp::Conflict)

      policy = ApplicationJobRetryPolicy::DEFAULT_ERROR_RETRY_ATTEMPTS
      expect(policy.keys).to include(::Ldp::Conflict)
      expect(policy[::Ldp::Conflict]).to eq(ApplicationJobRetryPolicy::DEFAULT_ERROR_RETRY_ATTEMPTS_COUNT)
    end

    it 'does not retry unknown standard errors' do
      error = StandardError.new('boom')

      expect(job.send(:configured_retry_attempts_for, error)).to be_nil
    end

    it 'retries runtime errors by class without message matching' do
      error = RuntimeError.new('some transient runtime failure')

      expect(job.send(:configured_retry_attempts_for, error)).to eq(ApplicationJobRetryPolicy::DEFAULT_ERROR_RETRY_ATTEMPTS_COUNT)
    end

    it 'retries Ldp::HttpError by class without message matching' do
      skip 'Ldp::HttpError is not available in this runtime' unless defined?(::Ldp::HttpError)

      error = ::Ldp::HttpError.new('non-standard upstream failure text')
      expect(job.send(:configured_retry_attempts_for, error)).to eq(ApplicationJobRetryPolicy::DEFAULT_ERROR_RETRY_ATTEMPTS_COUNT)
    end

    it 'retries Valkyrie::Persistence::StaleObjectError' do
      error = Valkyrie::Persistence::StaleObjectError.new('concurrent update detected')

      expect(job.send(:configured_retry_attempts_for, error)).to eq(ApplicationJobRetryPolicy::DEFAULT_ERROR_RETRY_ATTEMPTS_COUNT)
    end

    it 'uses lock-specific retry attempts for lock contention errors' do
      error = JobDistributedLock::LockUnavailableError.new('lock contention')

      expect(job.send(:configured_retry_attempts_for, error)).to eq(LockRetryProfiles::DefaultBackoff::LOCK_RETRY_ATTEMPTS)
    end

    it 'uses low-latency jittered wait for lock contention errors' do
      error = JobDistributedLock::LockUnavailableError.new('lock contention')
      allow(job).to receive(:executions).and_return(3)
      allow(job).to receive(:rand).and_return(1)

      expect(job.send(:configured_retry_wait_seconds_for, error)).to eq(5)
    end
  end

  describe '#retry_context_for_error' do
    it 'includes lock_contention and work_id context when available' do
      error = JobDistributedLock::LockUnavailableError.new('lock contention')
      allow(job).to receive(:arguments).and_return([{ work_id: 'work-123' }])
      allow(job).to receive(:executions).and_return(2)

      context = job.send(:retry_context_for_error, error: error, attempts: 30, wait_seconds: 7)

      expect(context[:lock_contention]).to be true
      expect(context[:work_id]).to eq('work-123')
      expect(context[:max_attempts]).to eq(30)
      expect(context[:wait_seconds]).to eq(7)
      expect(context[:error_class]).to eq('JobDistributedLock::LockUnavailableError')
    end

    it 'omits work_id when arguments are not a hash payload' do
      error = RuntimeError.new('transient failure')
      allow(job).to receive(:arguments).and_return(['not-a-hash'])
      allow(job).to receive(:executions).and_return(1)

      context = job.send(:retry_context_for_error, error: error, attempts: 10, wait_seconds: 2)

      expect(context[:lock_contention]).to be false
      expect(context).not_to have_key(:work_id)
    end
  end
end
