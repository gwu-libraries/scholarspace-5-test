# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Derivatives::WorkLevel::RepresentativeSelector do
  describe '#call' do
    it 'selects an octet-stream mp4 file as representative based on filename' do
      video_file_set = instance_double(
        'FileSet',
        id: 'video-1',
        audio?: false,
        video?: false,
        pdf?: false,
        image?: false,
        original_file: instance_double('OriginalFile', mime_type: 'application/octet-stream', original_filename: 'lecture.mp4')
      )
      work = instance_double(
        'Work',
        original_member_file_sets: [video_file_set],
        representative_id: nil
      )

      selector = described_class.new(work: work)
      allow(selector).to receive(:save_and_index).and_return(work)
      allow(work).to receive(:representative_id=)

      selector.call

      expect(work).to have_received(:representative_id=).with('video-1')
    end
  end
end