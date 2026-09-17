# frozen_string_literal: true

module Derivatives
  module Concerns
    module WorkLockable
      private

      WORK_ADVISORY_LOCK_TIMEOUT_SECONDS = DerivativeJobSettings.seconds(:work_advisory_lock, :timeout_seconds)

      def with_work_lock(work_id = nil)
        id = work_id || @work&.id
        raise ArgumentError, 'work_id is required for advisory lock' if id.blank?

        ActiveRecord::Base.with_advisory_lock!(
          advisory_lock_name(id),
          timeout_seconds: WORK_ADVISORY_LOCK_TIMEOUT_SECONDS
        ) do
          yield
        end
      rescue WithAdvisoryLock::FailedToAcquireLock => e
        raise JobDistributedLock::LockUnavailableError, "Could not acquire work advisory lock for work_id=#{id}: #{e.message}"
      end

      def advisory_lock_name(work_id)
        "scholarspace:derivatives:work:#{work_id}"
      end
    end
  end
end
