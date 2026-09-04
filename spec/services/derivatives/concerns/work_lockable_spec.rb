# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Derivatives::Concerns::WorkLockable do
  let(:test_class) do
    Class.new do
      include Derivatives::Concerns::WorkLockable
      public :with_work_lock, :advisory_lock_name
    end
  end

  subject(:service) { test_class.new }

  describe '#with_work_lock' do
    it 'raises ArgumentError when no work_id is available' do
      expect { service.with_work_lock }.to raise_error(ArgumentError, /work_id is required/)
    end

    it 'yields within a bounded advisory lock and returns the block result' do
      timeout = described_class::WORK_ADVISORY_LOCK_TIMEOUT_SECONDS
      allow(ActiveRecord::Base).to receive(:with_advisory_lock!)
        .with('scholarspace:derivatives:work:work-1', timeout_seconds: timeout)
        .and_yield.and_return(:done)

      expect(service.with_work_lock('work-1') { :done }).to eq(:done)
    end

    it 'converts a lock acquisition timeout into a retryable JobDistributedLock::LockUnavailableError' do
      allow(ActiveRecord::Base).to receive(:with_advisory_lock!)
        .and_raise(WithAdvisoryLock::FailedToAcquireLock.new('scholarspace:derivatives:work:work-1'))

      expect { service.with_work_lock('work-1') { :done } }
        .to raise_error(JobDistributedLock::LockUnavailableError, /work_id=work-1/)
    end
  end
end
