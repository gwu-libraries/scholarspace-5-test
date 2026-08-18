# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HyraxListener do
  subject(:listener) { described_class.new }

  describe '#on_file_characterized' do
    let(:file_set) { instance_double('FileSet', service_file: false) }
    let(:work) { instance_double('Work', id: 'work-1') }
    let(:custom_queries) { double('HyraxCustomQueries') }
    let(:delayed_job) { double('WorkLevelOrchestrateDelayedJob', perform_later: true) }

    before do
      allow(Hyrax).to receive(:custom_queries).and_return(custom_queries)
      allow(custom_queries).to receive(:find_parent_work).with(resource: file_set).and_return(work)
      allow(listener).to receive(:derivatives_enqueue_debounced?).with('work-1').and_return(false)
      allow(DerivativeJobs::WorkLevel::OrchestrateJob).to receive(:set).with(wait: 2.minutes).and_return(delayed_job)
    end

    it 'schedules derivative orchestration for characterized source file sets' do
      listener.on_file_characterized(file_set: file_set)

      expect(delayed_job).to have_received(:perform_later).with(work_id: 'work-1')
    end

    it 'does not schedule derivative orchestration for service file sets' do
      service_file_set = instance_double('FileSet', service_file: true)
      allow(custom_queries).to receive(:find_parent_work).with(resource: service_file_set).and_return(work)

      listener.on_file_characterized(file_set: service_file_set)

      expect(DerivativeJobs::WorkLevel::OrchestrateJob).not_to have_received(:set)
    end

    it 'does not schedule derivative orchestration when enqueue is debounced' do
      allow(listener).to receive(:derivatives_enqueue_debounced?).with('work-1').and_return(true)

      listener.on_file_characterized(file_set: file_set)

      expect(DerivativeJobs::WorkLevel::OrchestrateJob).not_to have_received(:set)
    end
  end

  describe '#derivatives_enqueue_debounced?' do
    it 'stores a per-work debounce key with the configured expiration' do
      redis = double('Redis')
      allow(Sidekiq).to receive(:redis).and_yield(redis)
      allow(redis).to receive(:set).and_return(true)

      result = listener.send(:derivatives_enqueue_debounced?, 'work-1')

      expect(redis).to have_received(:set).with(
        'derivatives:orchestration:scheduled:work-1',
        1,
        nx: true,
        ex: described_class::DERIVATIVES_ENQUEUE_DEBOUNCE.to_i
      )
      expect(result).to eq(false)
    end

    it 'reports debounced when the per-work key already exists' do
      redis = double('Redis')
      allow(Sidekiq).to receive(:redis).and_yield(redis)
      allow(redis).to receive(:set).and_return(false)

      result = listener.send(:derivatives_enqueue_debounced?, 'work-1')

      expect(result).to eq(true)
    end
  end
end
