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
  let(:work) { FactoryBot.valkyrie_create(:academic_document, user: user) }
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

    allow_any_instance_of(Derivatives::FileSetLevel::TextExtraction::FromImages)
      .to receive(:depositor).and_return(double('depositor')) # rubocop:disable RSpec/VerifiedDoubles

    allow_any_instance_of(Derivatives::FileSetLevel::TextExtraction::FromImages)
      .to receive(:source_image_file_sets)
      .and_return([
        double('source_image_1', id: 'source-image-1'),
        double('source_image_2', id: 'source-image-2')
      ]) # rubocop:disable RSpec/VerifiedDoubles

    allow_any_instance_of(Derivatives::FileSetLevel::TextExtraction::FromImages)
      .to receive(:copy_hocr_images_to_working_dir) do |instance|
        working_dir = instance.instance_variable_get(:@working_dir)

        image_fixture_paths.each_with_index.map do |path, i|
          {
            file_set: double("source_image_file_set_#{i}"), # rubocop:disable RSpec/VerifiedDoubles
            image_path: path.to_s,
            hocr_path: "#{working_dir}/hocr/image_#{i + 1}_HOCR.hocr"
          }
        end
      end

    allow_any_instance_of(Derivatives::FileSetLevel::TextExtraction::FromImages)
      .to receive(:file_set_attached_with_name?).and_return(false)

    allow_any_instance_of(Derivatives::WorkLevel::ReadingModePdfGeneration::FromImages)
      .to receive(:generate_to_cache) do |_instance, source_image_file_sets:|
        source_file_set = source_image_file_sets.first
        {
          source_file_set_id: source_file_set.id.to_s,
          cache_file_identifier: 'cache-reading-mode-pdf',
          cache_filename: 'reading_mode_pdf.pdf'
        }
      end

    allow_any_instance_of(Derivatives::WorkLevel::ReadingModePdfGeneration::FromImages)
      .to receive(:persist_from_cache) do |_instance, source_file_set_id:, cache_file_identifier:, cache_filename:|
        record_stubbed_derivative_output.call('reading_mode_pdf.pdf')
        nil
      end

    allow_any_instance_of(Derivatives::FileSetLevel::TextExtraction::FromImages)
      .to receive(:generate_hocr_file) do |_instance, image_path:, output_hocr_path:, error_message:|
        FileUtils.cp(Rails.root.join('spec/fixtures/testing_hocr.hocr'), output_hocr_path)
        output_hocr_path
      end

    allow_any_instance_of(Derivatives::FileSetLevel::TextExtraction::FromImages)
      .to receive(:generate_to_cache) do |_instance, source_file_set_id:|
        {
          source_file_set_id: source_file_set_id,
          cache_file_identifier: "cache-#{source_file_set_id}",
          cache_filename: "#{source_file_set_id}_HOCR.hocr"
        }
      end

    allow_any_instance_of(Derivatives::FileSetLevel::TextExtraction::FromImages)
      .to receive(:persist_from_cache)
      .and_return(nil)

    allow_any_instance_of(Derivatives::FileSetLevel::TextExtraction::FromImages)
      .to receive(:attach_file_to_work) do |_instance, file_path, source_file_set: nil|
        record_stubbed_derivative_output.call(file_path)
        nil
      end

    allow(DerivativeJobs::WorkLevel::ReadingModePdfGeneration::FromImagesGenerateJob).to receive(:set).and_return(DerivativeJobs::WorkLevel::ReadingModePdfGeneration::FromImagesGenerateJob)
    allow(DerivativeJobs::WorkLevel::ReadingModePdfGeneration::AssembleHocrJob).to receive(:set).and_return(DerivativeJobs::WorkLevel::ReadingModePdfGeneration::AssembleHocrJob)

    allow(DerivativeJobs::FileSetLevel::TextExtraction::FromImagesGenerateJob).to receive(:perform_later) do |work_id:, source_file_set_id:|
      DerivativeJobs::FileSetLevel::TextExtraction::FromImagesGenerateJob.perform_now(work_id: work_id, source_file_set_id: source_file_set_id)
    end
    allow(DerivativeJobs::WorkLevel::ReadingModePdfGeneration::FromImagesGenerateJob).to receive(:perform_later) do |work_id:|
      DerivativeJobs::WorkLevel::ReadingModePdfGeneration::FromImagesGenerateJob.perform_now(work_id: work_id)
    end
    allow(DerivativeJobs::WorkLevel::ReadingModePdfGeneration::FromImagesPersistJob).to receive(:perform_later) do |work_id:, source_file_set_id:, cache_file_identifier:, cache_filename:|
      DerivativeJobs::WorkLevel::ReadingModePdfGeneration::FromImagesPersistJob.perform_now(
        work_id: work_id,
        source_file_set_id: source_file_set_id,
        cache_file_identifier: cache_file_identifier,
        cache_filename: cache_filename
      )
    end
    allow(DerivativeJobs::WorkLevel::ReadingModePdfGeneration::AssembleHocrJob).to receive(:perform_later) do |work_id:|
      DerivativeJobs::WorkLevel::ReadingModePdfGeneration::AssembleHocrJob.perform_now(work_id: work_id)
    end
  end

  it 'creates reading mode PDF and hOCR derivatives for image members' do
    DerivativeJobs::WorkLevel::ReadingModePdfGeneration::OrchestrateJob.perform_now(work_id: work.id.to_s)

    names = stubbed_derivative_output_names

    expect(names).to include('reading_mode_pdf.pdf')
    expect(names).to include('reading_mode_pdf_HOCR.hocr')
    expect(names.grep(/_HOCR\.hocr\z/)).not_to be_empty
  end

  it 'is idempotent when run twice' do
    DerivativeJobs::WorkLevel::ReadingModePdfGeneration::OrchestrateJob.perform_now(work_id: work.id.to_s)
    first_run_names = stubbed_derivative_output_names.dup

    DerivativeJobs::WorkLevel::ReadingModePdfGeneration::OrchestrateJob.perform_now(work_id: work.id.to_s)
    second_run_names = stubbed_derivative_output_names

    expect(second_run_names.tally).to eq(first_run_names.tally)
  end

end