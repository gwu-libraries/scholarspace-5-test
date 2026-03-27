# frozen_string_literal: true

require 'rails_helper'
require_relative 'support/derivatives_feature_helpers'

RSpec.describe 'Images to PDF derivatives end-to-end', type: :feature do
  include DerivativesFeatureHelpers

  let(:user) do
    User.create!(
      email: "spec-images-to-pdf-#{SecureRandom.uuid}@example.edu",
      password: 'Password123!',
      password_confirmation: 'Password123!'
    ).tap do |u|
      admin_role = Role.find_or_create_by(name: 'admin')
      u.roles << admin_role unless u.roles.exists?(id: admin_role.id)
    end
  end
  let(:work) { FactoryBot.valkyrie_create(:academic_document, user: user, with_admin_set: true) }
  let(:image_fixture_paths) do
    [
      Rails.root.join('spec/fixtures/tiffs/test_tiff_01.tiff'),
      Rails.root.join('spec/fixtures/tiffs/test_tiff_02.tiff')
    ]
  end

  before do
    work.depositor = user.email
    Hyrax.persister.save(resource: work)

    image_fixture_paths.each do |fixture_path|
      attach_fixture_to_work(work: work, user: user, fixture_path: fixture_path)
    end
  end

  it 'creates joined PDF and hOCR derivatives for image members' do
    ImagesToPdfDerivativesJob.perform_now(work_id: work.id.to_s)

    names = member_filenames_for(work)

    expect(names).to include('joined_images_derivative.pdf')
    expect(names.grep(/_HOCR\.hocr\z/)).not_to be_empty
  end

  it 'is idempotent when run twice' do
    ImagesToPdfDerivativesJob.perform_now(work_id: work.id.to_s)

    ImagesToPdfDerivativesJob.perform_now(work_id: work.id.to_s)
    second_run_names = member_filenames_for(work)

    expect(second_run_names.tally.values.max).to eq(1)
  end

end