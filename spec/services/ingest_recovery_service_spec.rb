# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IngestRecoveryService do
  let(:stale_upload) { instance_double(Hyrax::UploadedFile, id: 139, file_set_uri: 'file-set-1') }
  let(:fresh_upload) { instance_double(Hyrax::UploadedFile, id: 140, file_set_uri: 'file-set-2') }
  let(:base_scope) { double('UploadedFileBaseScope') }
  let(:scope) { double('UploadedFileScope') }

  before do
    redis = instance_double(Redis)
    allow(Sidekiq).to receive(:redis).and_yield(redis)
    allow(redis).to receive(:set).with(described_class::LOCK_KEY, 1, nx: true, ex: described_class::LOCK_TIMEOUT_SECONDS).and_return(true)
    allow(Hyrax::UploadedFile).to receive(:where).and_return(base_scope)
    allow(base_scope).to receive(:not).with(file_set_uri: [nil, '']).and_return(scope)
    allow(scope).to receive(:where).with('updated_at < ?', kind_of(ActiveSupport::TimeWithZone)).and_return(scope)
    allow(scope).to receive(:find_each).and_yield(stale_upload).and_yield(fresh_upload)
    allow(stale_upload).to receive(:touch)
    allow(fresh_upload).to receive(:touch)
  end

  it 'requeues only stale uploads whose file sets lack an original file' do
    incomplete_file_set = instance_double(Hyrax::FileSet, original_file: nil)
    completed_file_set = instance_double(Hyrax::FileSet, original_file: instance_double('OriginalFile'))
    allow(Hyrax.query_service).to receive(:find_by).with(id: Valkyrie::ID.new('file-set-1')).and_return(incomplete_file_set)
    allow(Hyrax.query_service).to receive(:find_by).with(id: Valkyrie::ID.new('file-set-2')).and_return(completed_file_set)
    allow_any_instance_of(described_class).to receive(:upload_available?).with(stale_upload).and_return(true)
    allow(ValkyrieIngestJob).to receive(:perform_later)

    result = described_class.call

    expect(result).to eq(1)
    expect(ValkyrieIngestJob).to have_received(:perform_later).with(stale_upload)
    expect(ValkyrieIngestJob).not_to have_received(:perform_later).with(fresh_upload)
    expect(stale_upload).to have_received(:touch)
  end
end
