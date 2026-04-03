# frozen_string_literal: true

module ScholarspaceDerivativesServices
  module Concerns
    module WorkLockable
    private

    def with_work_lock(work_id = nil)
      id = work_id || @work&.id
      raise ArgumentError, 'work_id is required for advisory lock' if id.blank?

      ActiveRecord::Base.with_advisory_lock(advisory_lock_name(id)) do
        yield
      end
    end

    def advisory_lock_name(work_id)
      "scholarspace:derivatives:work:#{work_id}"
    end
    end
  end
end
