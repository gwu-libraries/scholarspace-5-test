# frozen_string_literal: true

require 'rails_helper'
require_relative 'support/derivatives_feature_helpers'

RSpec.describe 'Audio transcript derivatives end-to-end', type: :feature do
  include DerivativesFeatureHelpers

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
    work.depositor = user.email
    Hyrax.persister.save(resource: work)

    attach_fixture_to_work(work: work, user: user, fixture_path: audio_fixture_path)
  end

  it 'creates a VTT transcript attachment from source audio' do
    AudioTranscriptDerivativesJob.perform_now(work_id: work.id.to_s)

    names = member_filenames_for(work)

    expect(names.grep(/\.vtt\z/)).not_to be_empty
  end

  it 'is idempotent when run twice' do
    AudioTranscriptDerivativesJob.perform_now(work_id: work.id.to_s)
    first_run_names = member_filenames_for(work)

    AudioTranscriptDerivativesJob.perform_now(work_id: work.id.to_s)
    second_run_names = member_filenames_for(work)

    expect(second_run_names.tally).to eq(first_run_names.tally)
  end

end