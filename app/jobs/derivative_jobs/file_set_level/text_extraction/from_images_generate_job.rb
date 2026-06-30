# frozen_string_literal: true

class DerivativeJobs::FileSetLevel::TextExtraction::FromImagesGenerateJob < ApplicationJob
  queue_as :derivatives_text_extraction_from_images_generate

  def perform(work_id:, source_file_set_id:)
    Rails.logger.info(
      "derivative_pipeline event=image_text_generate_start work_id=#{work_id} " \
      "source_file_set_id=#{source_file_set_id} job_id=#{job_id} queue=#{queue_name}"
    )

    with_work(work_id: work_id) do |work|
      payload = Derivatives::FileSetLevel::TextExtraction::FromImages
                .new(work)
                .process_image_file_set_to_cache(source_file_set_id: source_file_set_id)

      next unless payload

      DerivativeJobs::FileSetLevel::TextExtraction::FromImagesPersistJob.perform_later(
        work_id: work.id.to_s,
        source_file_set_id: payload.fetch(:source_file_set_id),
        cache_file_identifier: payload.fetch(:cache_file_identifier),
        cache_filename: payload.fetch(:cache_filename)
      )
    end
  end
end
