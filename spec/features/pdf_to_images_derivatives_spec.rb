# frozen_string_literal: true

require 'rails_helper'
require_relative 'support/derivatives_feature_helpers'

RSpec.describe 'PDF to images derivatives end-to-end', type: :feature do
  include DerivativesFeatureHelpers

  let(:user) do
    User.create!(
      email: "spec-pdf-to-images-#{SecureRandom.uuid}@example.edu",
      password: 'Password123!',
      password_confirmation: 'Password123!'
    ).tap do |u|
      admin_role = Role.find_or_create_by(name: 'admin')
      u.roles << admin_role unless u.roles.exists?(id: admin_role.id)
    end
  end
  let(:work) { FactoryBot.valkyrie_create(:academic_document, user: user, with_admin_set: true) }
  let(:pdf_fixture_path) { Rails.root.join('spec/fixtures/testing_pdf_no_pre_ocr.pdf') }

  before do
    work.depositor = user.email
    Hyrax.persister.save(resource: work)

    attach_fixture_to_work(work: work, user: user, fixture_path: pdf_fixture_path)
  end

  it 'creates split page images and hOCR derivatives for source PDF' do
    PdfToImagesDerivativesJob.perform_now(work_id: work.id.to_s)

    names = member_filenames_for(work)

    expect(names.grep(/_page_\d{4}\.jpg\z/)).not_to be_empty
    expect(names.grep(/_HOCR\.hocr\z/)).not_to be_empty
  end

  it 'is idempotent when run twice' do
    PdfToImagesDerivativesJob.perform_now(work_id: work.id.to_s)
    first_run_names = member_filenames_for(work)

    PdfToImagesDerivativesJob.perform_now(work_id: work.id.to_s)
    second_run_names = member_filenames_for(work)

    expect(second_run_names.tally).to eq(first_run_names.tally)
  end

end