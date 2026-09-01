# frozen_string_literal: true

class DerivativeJobs::WorkLevel::ReadingModePdfGeneration::AssembleHocrJob < ApplicationJob
  include JobDistributedLock
  include LockRetryProfiles::LongRunningShortBackoff

  queue_as :derivatives_reading_mode_pdf_generation_assemble_hocr

  def perform(work_id:)
    Rails.logger.info(
      "derivative_pipeline event=image_hocr_assemble_start work_id=#{work_id} " \
      "job_id=#{job_id} queue=#{queue_name}"
    )

    with_work(work_id: work_id) do |work|
      hocr_file_set_id = Derivatives::FileSetLevel::TextExtraction::FromImages.new(work).assemble_joined_hocr!
      Rails.logger.info(
        "derivative_pipeline event=image_hocr_assemble_done work_id=#{work_id} " \
        "joined_hocr_file_set_id=#{hocr_file_set_id}"
      )
    end
  end

  protected

  def lock_key_for(arguments)
    "derivatives:reading_mode_pdf_generation:work:#{arguments[:work_id]}:assemble_hocr"
  end
end