# frozen_string_literal: true

require 'fileutils'
require 'rails_helper'

RSpec.describe 'PDF to images derivatives end-to-end', type: :feature do
  let(:stubbed_derivative_output_names) { [] }

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
    record_stubbed_derivative_output = lambda do |path_or_name|
      name = File.basename(path_or_name.to_s)
      stubbed_derivative_output_names << name unless stubbed_derivative_output_names.include?(name)
    end

    allow_any_instance_of(ScholarspaceDerivativesServices::PdfToImagesDerivativesService)
      .to receive(:depositor).and_return(double('depositor'))

    allow_any_instance_of(ScholarspaceDerivativesServices::PdfToImagesDerivativesService)
      .to receive(:source_pdf_file_sets).and_return([double('source_pdf_file_set')])

    allow_any_instance_of(ScholarspaceDerivativesServices::PdfToImagesDerivativesService)
      .to receive(:pdf_already_split?).and_return(false)

    allow_any_instance_of(ScholarspaceDerivativesServices::PdfToImagesDerivativesService)
      .to receive(:copy_pdf_to_working_dir).and_return(pdf_fixture_path.to_s)

    allow_any_instance_of(ScholarspaceDerivativesServices::PdfToImagesDerivativesService)
      .to receive(:file_set_attached_with_name?).and_return(false)

    allow_any_instance_of(ScholarspaceDerivativesServices::PdfToImagesDerivativesService)
      .to receive(:split_pdf_to_images) do |instance, _pdf_path, _pdf_file_set|
        working_dir = instance.instance_variable_get(:@working_dir)
        image_path = "#{working_dir}/images/source_derivative_page_0001.jpg"
        FileUtils.touch(image_path)
        [image_path]
      end

    allow_any_instance_of(ScholarspaceDerivativesServices::PdfToImagesDerivativesService)
      .to receive(:generate_hocr_file) do |_instance, image_path:, output_hocr_path:, error_message:|
        FileUtils.cp(Rails.root.join('spec/fixtures/testing_hocr.hocr'), output_hocr_path)
        output_hocr_path
      end

    allow_any_instance_of(ScholarspaceDerivativesServices::PdfToImagesDerivativesService)
      .to receive(:attach_files_to_work) do |_instance, file_paths, source_file_set:|
        file_paths.each { |path| record_stubbed_derivative_output.call(path) }
        []
      end

    allow_any_instance_of(ScholarspaceDerivativesServices::PdfToImagesDerivativesService)
      .to receive(:attach_images_to_work) do |_instance, image_paths, source_file_set:|
        image_paths.each { |path| record_stubbed_derivative_output.call(path) }
        []
      end
  end

  it 'creates split page images and hOCR derivatives for source PDF' do
    PdfToImagesDerivativesJob.perform_now(work_id: work.id.to_s)

    names = stubbed_derivative_output_names

    expect(names.grep(/_page_\d{4}\.jpg\z/)).not_to be_empty
    expect(names.grep(/_HOCR\.hocr\z/)).not_to be_empty
  end

  it 'is idempotent when run twice' do
    PdfToImagesDerivativesJob.perform_now(work_id: work.id.to_s)
    first_run_names = stubbed_derivative_output_names.dup

    PdfToImagesDerivativesJob.perform_now(work_id: work.id.to_s)
    second_run_names = stubbed_derivative_output_names

    expect(second_run_names.tally).to eq(first_run_names.tally)
  end

end