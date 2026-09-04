# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DerivativeJobs::WorkLevel::ReindexJob do
  let(:work) { instance_double('Work', id: 'work-1') }
  let(:index_adapter) { instance_double('IndexAdapter') }
  let(:redis) { Sidekiq.redis { |connection| connection } }

  before do
    allow(Hyrax.query_service).to receive(:find_by).with(id: 'work-1').and_return(work)
    allow(Hyrax).to receive(:index_adapter).and_return(index_adapter)
    allow(index_adapter).to receive(:save)
    redis.del('derivatives:work_reindex:scheduled:work-1')
  end

  after do
    redis.del('derivatives:work_reindex:scheduled:work-1')
  end

  it 'indexes the latest work without saving it to Fedora' do
    described_class.perform_now(work_id: 'work-1')

    expect(index_adapter).to have_received(:save).with(resource: work)
  end

  it 'schedules only one reindex while the debounce key is present' do
    allow(described_class).to receive(:set).and_return(described_class)
    allow(described_class).to receive(:perform_later)

    described_class.schedule(work_id: 'work-1')
    described_class.schedule(work_id: 'work-1')

    expect(described_class).to have_received(:perform_later).once.with(work_id: 'work-1')
  end
end
