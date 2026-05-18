# frozen_string_literal: true

require 'fileutils'
require 'rails_helper'

RSpec.describe 'Audio transcript derivatives end-to-end', type: :feature do
  let(:stubbed_derivative_output_names) { [] }

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
  let(:work) { FactoryBot.valkyrie_create(:academic_document, user: user, with_admin_set: true) }
  let(:audio_fixture_path) { Rails.root.join('spec/fixtures/testing_mp4.mp4') }

  before do
    record_stubbed_derivative_output = lambda do |path_or_name|
      name = File.basename(path_or_name.to_s)
      stubbed_derivative_output_names << name unless stubbed_derivative_output_names.include?(name)
    end

    allow_any_instance_of(ScholarspaceDerivativesServices::AudioTranscriptDerivativesService)
      .to receive(:transcription_source_path) { |_instance, file_path| file_path }

    allow_any_instance_of(ScholarspaceDerivativesServices::AudioTranscriptDerivativesService)
      .to receive(:copy_av_files_to_working_dir)
      .and_return([{ file_set: double('audio_source_file_set'), path: audio_fixture_path.to_s }])

    allow_any_instance_of(ScholarspaceDerivativesServices::AudioTranscriptDerivativesService)
      .to receive(:generate_vtt) do |_instance, *_args, **kwargs|
        vtt_path = "#{kwargs[:output_dir]}/#{kwargs[:title]}_VTT.vtt"
        FileUtils.cp(Rails.root.join('spec/fixtures/testing_vtt.vtt'), vtt_path)
        vtt_path
      end

    allow_any_instance_of(ScholarspaceDerivativesServices::AudioTranscriptDerivativesService)
      .to receive(:attach_vtt_to_work) do |_instance, vtt_path, source_file_set:|
        record_stubbed_derivative_output.call(vtt_path)
        true
      end
  end

  it 'creates a VTT transcript attachment from source audio' do
    AudioTranscriptDerivativesJob.perform_now(work_id: work.id.to_s)

    names = stubbed_derivative_output_names

    expect(names.grep(/\.vtt\z/)).not_to be_empty
  end

  it 'is idempotent when run twice' do
    AudioTranscriptDerivativesJob.perform_now(work_id: work.id.to_s)
    first_run_names = stubbed_derivative_output_names.dup

    AudioTranscriptDerivativesJob.perform_now(work_id: work.id.to_s)
    second_run_names = stubbed_derivative_output_names

    expect(second_run_names.tally).to eq(first_run_names.tally)
  end

end