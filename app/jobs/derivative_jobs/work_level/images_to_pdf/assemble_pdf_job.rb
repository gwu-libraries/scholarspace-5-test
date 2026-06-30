# frozen_string_literal: true

class DerivativeJobs::WorkLevel::ImagesToPdf::AssemblePdfJob < ApplicationJob
  include JobDistributedLock
  include LockRetryProfiles::ShortBackoff

  queue_as :derivatives_images_to_pdf_assemble_pdf

  def perform(work_id:)
    Rails.logger.info(
      "derivative_pipeline event=image_pdf_assemble_start work_id=#{work_id} " \
      "job_id=#{job_id} queue=#{queue_name}"
    )

    with_work(work_id: work_id) do |work|
      pdf_file_set_id = Derivatives::WorkLevel::PdfGeneration::FromImages.new(work).assemble_joined_pdf!(
        source_image_file_sets: Derivatives::FileSetLevel::TextExtraction::FromImages.new(work).source_image_file_sets
      )
      Rails.logger.info(
        "derivative_pipeline event=image_pdf_assemble_done work_id=#{work_id} " \
        "joined_pdf_file_set_id=#{pdf_file_set_id}"
      )
    end
  end

  protected

  def lock_key_for(arguments)
    "derivatives:images_to_pdf:work:#{arguments[:work_id]}:assemble_pdf"
  end
end