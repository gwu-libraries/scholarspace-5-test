# frozen_string_literal: true

require 'fileutils'
require 'rails_helper'

RSpec.describe 'Audio transcript derivatives end-to-end', type: :feature do
  let(:stubbed_derivative_output_names) { [] }
  let(:source_file_set_id) { 'source-av-1' }
  let(:cache_filename) { 'testing_mp4_VTT.vtt' }

  let(:user) do
    User.create!(
      email: "spec-audio-transcript-#{SecureRandom.uuid}@example.edu",
      password: 'Password123!',
      password_confirmation: 'Password123!'
    ).tap do |u|
      admin_role = Role.find_or_create_by(name: 'admin')
      u.roles << admin_role unless u.roles.exists?(id: admin_role.id)
    end
  end
  let(:work) { FactoryBot.valkyrie_create(:academic_document, user: user) }
  let(:audio_fixture_path) { Rails.root.join('spec/fixtures/testing_mp4.mp4') }

  before do
    record_stubbed_derivative_output = lambda do |path_or_name|
      name = File.basename(path_or_name.to_s)
      stubbed_derivative_output_names << name unless stubbed_derivative_output_names.include?(name)
    end

    entrypoint = instance_double(Derivatives::FileSetLevel::TranscriptExtraction::FromAudioVideo)
  allow(Derivatives::FileSetLevel::TranscriptExtraction::FromAudioVideo).to receive(:new).and_return(entrypoint)
    allow(entrypoint).to receive(:source_file_set_ids).and_return([source_file_set_id])

    allow(DerivativeJobs::FileSetLevel::AudioTranscript::GenerateJob).to receive(:perform_later) do |**args|
      DerivativeJobs::FileSetLevel::AudioTranscript::GenerateJob.perform_now(**args)
    end

    allow(DerivativeJobs::FileSetLevel::AudioTranscript::PersistJob).to receive(:perform_later) do |**args|
      DerivativeJobs::FileSetLevel::AudioTranscript::PersistJob.perform_now(**args)
    end

    allow(entrypoint)
      .to receive(:generate_for_source_file_set_to_cache)
      .and_return(
        {
          source_file_set_id: source_file_set_id,
          cache_file_identifier: 'cache-audio-1',
          cache_filename: cache_filename
        }
      )

    allow(entrypoint)
      .to receive(:persist_transcript_from_cache) do |source_file_set_id:, cache_file_identifier:, cache_filename:|
        expect(source_file_set_id).to be_present
        expect(cache_file_identifier).to be_present
        record_stubbed_derivative_output.call(cache_filename)
        true
      end
  end

  it 'creates a VTT transcript attachment from source audio' do
    DerivativeJobs::FileSetLevel::AudioTranscript::GenerateJob.perform_now(
      work_id: work.id.to_s,
      source_file_set_id: source_file_set_id
    )

    names = stubbed_derivative_output_names

    expect(names.grep(/\.vtt\z/)).not_to be_empty
  end

  it 'is idempotent when run twice' do
    DerivativeJobs::FileSetLevel::AudioTranscript::GenerateJob.perform_now(
      work_id: work.id.to_s,
      source_file_set_id: source_file_set_id
    )
    first_run_names = stubbed_derivative_output_names.dup

    DerivativeJobs::FileSetLevel::AudioTranscript::GenerateJob.perform_now(
      work_id: work.id.to_s,
      source_file_set_id: source_file_set_id
    )
    second_run_names = stubbed_derivative_output_names

    expect(second_run_names.tally).to eq(first_run_names.tally)
  end

end