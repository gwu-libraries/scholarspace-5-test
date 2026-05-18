# frozen_string_literal: true

require 'fileutils'
require 'rails_helper'

RSpec.describe 'Images to PDF derivatives end-to-end', type: :feature do
  let(:stubbed_derivative_output_names) { [] }

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
    record_stubbed_derivative_output = lambda do |path_or_name|
      name = File.basename(path_or_name.to_s)
      stubbed_derivative_output_names << name unless stubbed_derivative_output_names.include?(name)
    end

    allow_any_instance_of(ScholarspaceDerivativesServices::ImagesToPdfDerivativesService)
      .to receive(:depositor).and_return(double('depositor')) # rubocop:disable RSpec/VerifiedDoubles

    allow_any_instance_of(ScholarspaceDerivativesServices::ImagesToPdfDerivativesService)
      .to receive(:source_image_file_sets)
      .and_return([double('source_image_1'), double('source_image_2')]) # rubocop:disable RSpec/VerifiedDoubles

    allow_any_instance_of(ScholarspaceDerivativesServices::ImagesToPdfDerivativesService)
      .to receive(:file_set_attached_with_name?).and_return(false)

    allow_any_instance_of(ScholarspaceDerivativesServices::ImagesToPdfDerivativesService)
      .to receive(:copy_images_to_working_dir) do |instance|
        working_dir = instance.instance_variable_get(:@working_dir)

        image_fixture_paths.each_with_index.map do |path, i|
          {
            file_set: double("source_image_file_set_#{i}"), # rubocop:disable RSpec/VerifiedDoubles
            image_path: path.to_s,
            hocr_path: "#{working_dir}/hocr/image_#{i + 1}_HOCR.hocr"
          }
        end
      end

    allow_any_instance_of(ScholarspaceDerivativesServices::ImagesToPdfDerivativesService)
      .to receive(:generate_hocr_file) do |_instance, image_path:, output_hocr_path:, error_message:|
        FileUtils.cp(Rails.root.join('spec/fixtures/testing_hocr.hocr'), output_hocr_path)
        output_hocr_path
      end

    allow_any_instance_of(ScholarspaceDerivativesServices::ImagesToPdfDerivativesService)
      .to receive(:join_images_to_pdf) do |instance, _image_paths|
        working_dir = instance.instance_variable_get(:@working_dir)
        FileUtils.mkdir_p("#{working_dir}/pdfs")
        joined_path = "#{working_dir}/pdfs/#{instance.joined_pdf_filename}"
        FileUtils.touch(joined_path)
        instance.instance_variable_set(:@joined_pdf_path, joined_path)
      end

    allow_any_instance_of(ScholarspaceDerivativesServices::ImagesToPdfDerivativesService)
      .to receive(:attach_file_to_work) do |_instance, file_path, source_file_set: nil|
        record_stubbed_derivative_output.call(file_path)
        nil
      end
  end

  it 'creates joined PDF and hOCR derivatives for image members' do
    ImagesToPdfDerivativesJob.perform_now(work_id: work.id.to_s)

    names = stubbed_derivative_output_names

    expect(names).to include('joined_images_pdf.pdf')
    expect(names).to include('joined_images_pdf_HOCR.hocr')
    expect(names.grep(/_HOCR\.hocr\z/)).not_to be_empty
  end

  it 'is idempotent when run twice' do
    ImagesToPdfDerivativesJob.perform_now(work_id: work.id.to_s)
    first_run_names = stubbed_derivative_output_names.dup

    ImagesToPdfDerivativesJob.perform_now(work_id: work.id.to_s)
    second_run_names = stubbed_derivative_output_names

    expect(second_run_names.tally).to eq(first_run_names.tally)
  end

end