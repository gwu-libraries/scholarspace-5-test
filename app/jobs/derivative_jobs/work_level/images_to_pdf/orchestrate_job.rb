# frozen_string_literal: true

class DerivativeJobs::WorkLevel::ImagesToPdf::OrchestrateJob < ApplicationJob
  queue_as :derivatives_images_to_pdf_orchestrate

  def perform(work_id:)
    with_work(work_id: work_id) do |work|
      source_image_file_set_ids = Derivatives::FileSetLevel::TextExtraction
                  .from_images
                  .source_image_file_set_ids(work)

      return if source_image_file_set_ids.empty?

      Rails.logger.info(
        "derivative_pipeline event=image_text_orchestrate_start work_id=#{work.id} " \
        "image_count=#{source_image_file_set_ids.size} job_id=#{job_id} queue=#{queue_name}"
      )

      source_image_file_set_ids.each do |source_file_set_id|
        DerivativeJobs::FileSetLevel::TextExtraction::FromImagesGenerateJob.perform_later(
          work_id: work.id.to_s,
          source_file_set_id: source_file_set_id
        )
      end

      DerivativeJobs::WorkLevel::ImagesToPdf::AssemblePdfJob
        .set(wait: 2.minutes)
        .perform_later(work_id: work.id.to_s)

      DerivativeJobs::WorkLevel::ImagesToPdf::AssembleHocrJob
        .set(wait: 3.minutes)
        .perform_later(work_id: work.id.to_s)

      Rails.logger.info(
        "derivative_pipeline event=image_text_orchestrate_enqueued work_id=#{work.id} " \
        "generate_jobs=#{source_image_file_set_ids.size} " \
        "queues=derivatives_text_extraction_from_images_generate,derivatives_images_to_pdf_assemble_pdf,derivatives_images_to_pdf_assemble_hocr"
      )
    end
  end
end
