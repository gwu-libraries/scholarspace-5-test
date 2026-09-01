# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DerivativeJobs::FileSetLevel::Thumbnail::PersistJob do
  describe '#lock_key_for' do
    it 'locks per work and source file set' do
      key = described_class.new.send(
        :lock_key_for,
        { work_id: 'work-1', source_file_set_id: 'source-9' }
      )

      expect(key).to eq('derivatives:thumbnail:work:work-1:source:source-9:persist')
    end
  end
end
