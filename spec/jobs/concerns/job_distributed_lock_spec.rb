# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobDistributedLock do
  # Test job that uses distributed locking
  class LockedTestJob < ApplicationJob
    include JobDistributedLock

    ERROR_RETRY_ATTEMPTS = {
      RuntimeError => 0
    }.freeze
    LOCK_RETRY_ATTEMPTS = 0

    attr_accessor :executed, :work_id

    def perform(work_id: nil)
      @work_id = work_id
      @executed = true
    end

    protected

    def lock_key_for(arguments)
      return nil if arguments.blank?

      work_id_val = arguments[:work_id] || 'unknown'
      "test:work:#{work_id_val}"
    end
  end

  describe 'distributed locking' do
    let(:work_id) { 'test-work-123' }
    let(:redis_client) { Sidekiq.redis { |r| r } }

    before do
      redis_client.del("test:work:#{work_id}")
      redis_client.del('test:work:work-1')
      redis_client.del('test:work:work-2')
    end

    it 'acquires lock and executes the job' do
      job = LockedTestJob.new(work_id: work_id)
      job.perform_now

      expect(job.executed).to be true
      expect(job.work_id).to eq(work_id)
    end

    it 'releases lock after job completes' do
      lock_key = "test:work:#{work_id}"

      # Ensure no lock exists initially
      redis_client.del(lock_key)

      LockedTestJob.new(work_id: work_id).perform_now

      # Lock should be released (not in Redis)
      expect(redis_client.exists(lock_key)).to eq(0)
    end

    it 'prevents concurrent execution by rejecting second job without lock' do
      lock_key = "test:work:#{work_id}"

      # Manually set lock to simulate first job holding it
      redis_client.set(lock_key, 'some-token', ex: 3600, nx: true)

      # Second job should fail to acquire lock and raise
      expect do
        LockedTestJob.new(work_id: work_id).perform_now
      end.to raise_error(RuntimeError, /Could not acquire lock/)

      # Cleanup
      redis_client.del(lock_key)
    end

    it 'allows different work_ids to execute concurrently' do
      work_id_1 = 'work-1'
      work_id_2 = 'work-2'
      lock_key_1 = "test:work:#{work_id_1}"

      # Set lock for work_id_1
      redis_client.set(lock_key_1, 'some-token', ex: 3600, nx: true)

      # Job for work_id_2 should execute successfully (different lock key)
      job2 = LockedTestJob.new(work_id: work_id_2)
      job2.perform_now

      expect(job2.executed).to be true
      expect(job2.work_id).to eq(work_id_2)

      # Cleanup
      redis_client.del(lock_key_1)
    end
  end
end
