# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DerivativeJobs::WorkLevel::ReadingModePdfGeneration::AssembleHocrJob do
  describe 'lock configuration' do
    it 'uses the long-running short-backoff lock profile' do
      expect(described_class::LOCK_TIMEOUT_SECONDS).to eq(LockRetryProfiles::LongRunningShortBackoff::LOCK_TIMEOUT_SECONDS)
      expect(described_class::LOCK_RETRY_ATTEMPTS).to eq(LockRetryProfiles::LongRunningShortBackoff::LOCK_RETRY_ATTEMPTS)
    end
  end

  describe 'queue configuration' do
    it 'uses the image hOCR assembly queue' do
      expect(described_class.queue_name).to eq('derivatives_reading_mode_pdf_generation_assemble_hocr')
    end
  end

  describe '#lock_key_for' do
    it 'locks only image hOCR assembly per work' do
      key = described_class.new.send(:lock_key_for, { work_id: 'work-1' })

      expect(key).to eq('derivatives:reading_mode_pdf_generation:work:work-1:assemble_hocr')
    end
  end
end