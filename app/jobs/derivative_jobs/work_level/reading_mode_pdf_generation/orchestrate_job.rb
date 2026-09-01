# frozen_string_literal: true

class DerivativeJobs::WorkLevel::ReadingModePdfGeneration::OrchestrateJob < ApplicationJob
  queue_as :derivatives_reading_mode_pdf_generation_orchestrate

  FROM_IMAGES_GENERATE_WAIT = DerivativeJobSettings.seconds(:waits, :reading_mode_pdf_generation, :from_images_generate_seconds).seconds
  ASSEMBLE_HOCR_WAIT = DerivativeJobSettings.seconds(:waits, :reading_mode_pdf_generation, :assemble_hocr_seconds).seconds
  ORCHESTRATION_DEBOUNCE = [FROM_IMAGES_GENERATE_WAIT, ASSEMBLE_HOCR_WAIT].max

  def perform(work_id:)
    with_work(work_id: work_id) do |work|
      source_image_file_set_ids = Derivatives::FileSetLevel::TextExtraction::FromImages
                                  .source_image_file_set_ids(work)

      return if source_image_file_set_ids.empty?
      return if orchestration_debounced?(work.id.to_s)

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

      DerivativeJobs::WorkLevel::ReadingModePdfGeneration::FromImagesGenerateJob
        .set(wait: FROM_IMAGES_GENERATE_WAIT)
        .perform_later(work_id: work.id.to_s)

      DerivativeJobs::WorkLevel::ReadingModePdfGeneration::AssembleHocrJob
        .set(wait: ASSEMBLE_HOCR_WAIT)
        .perform_later(work_id: work.id.to_s)

      Rails.logger.info(
        "derivative_pipeline event=image_text_orchestrate_enqueued work_id=#{work.id} " \
        "generate_jobs=#{source_image_file_set_ids.size} " \
        "queues=derivatives_text_extraction_from_images_generate,derivatives_reading_mode_pdf_generation_from_images_generate,derivatives_reading_mode_pdf_generation_assemble_hocr"
      )
    end
  end

  private

  def orchestration_debounced?(work_id)
    cache_key = "derivatives:reading_mode_pdf_generation:orchestrated:#{work_id}"
    scheduled = Sidekiq.redis { |redis| redis.set(cache_key, 1, nx: true, ex: ORCHESTRATION_DEBOUNCE.to_i) }
    !scheduled
  end
end
