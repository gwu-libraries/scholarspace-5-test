# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DerivativeJobs::WorkLevel::RepresentativeThumbnail::GenerateJob do
  describe '#perform' do
    it 'enqueues representative thumbnail persist job when payload is present' do
      work = instance_double('Work', id: 'work-1')
      service = instance_double(Derivatives::WorkLevel::RepresentativeThumbnail::FromSourceFileSet)
      payload = {
        source_file_set_id: 'src-1',
        cache_file_identifier: 'cache-representative-thumbnail',
        cache_filename: 'REPRESENTATIVE_THUMBNAIL.jpg'
      }

      allow(Hyrax.query_service).to receive(:find_by).with(id: 'work-1').and_return(work)
      allow(Derivatives::WorkLevel::RepresentativeThumbnail::FromSourceFileSet).to receive(:new).with(work).and_return(service)
      allow(service).to receive(:generate_to_cache).and_return(payload)
      allow(DerivativeJobs::WorkLevel::RepresentativeThumbnail::PersistJob).to receive(:perform_later)

      described_class.new.perform(work_id: 'work-1')

      expect(DerivativeJobs::WorkLevel::RepresentativeThumbnail::PersistJob).to have_received(:perform_later).with(
        work_id: 'work-1',
        source_file_set_id: 'src-1',
        cache_file_identifier: 'cache-representative-thumbnail',
        cache_filename: 'REPRESENTATIVE_THUMBNAIL.jpg'
      )
    end
  end

  describe '#lock_key_for' do
    it 'locks representative generate per work' do
      key = described_class.new.send(:lock_key_for, { work_id: 'work-1' })

      expect(key).to eq('derivatives:representative_thumbnail:work:work-1:generate')
    end
  end
end
