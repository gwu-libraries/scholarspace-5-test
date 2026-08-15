# frozen_string_literal: true

class DerivativeJobs::FileSetLevel::TextExtraction::FromPdfGenerateJob < ApplicationJob
  include JobDistributedLock

  queue_as :derivatives_text_extraction_from_pdf_generate

  def perform(work_id:, pdf_file_set_id: nil)
    target_pdf_file_set_id = pdf_file_set_id.presence
    return if target_pdf_file_set_id.blank?

    Rails.logger.info(
      "derivative_pipeline event=pdf_text_generate_start work_id=#{work_id} " \
      "pdf_file_set_id=#{target_pdf_file_set_id} job_id=#{job_id} queue=#{queue_name}"
    )

    with_work(work_id: work_id) do |work|
      payload = Derivatives::FileSetLevel::TextExtraction::FromPdf
                .new(work)
                .generate_to_cache(pdf_file_set_id: target_pdf_file_set_id)

      next unless payload

      DerivativeJobs::FileSetLevel::TextExtraction::FromPdfPersistJob.perform_later(
        work_id: work.id.to_s,
        source_file_set_id: payload.fetch(:source_file_set_id),
        cache_file_identifier_hocr: payload.fetch(:cache_file_identifier_hocr),
        cache_filename_hocr: payload.fetch(:cache_filename_hocr),
        cache_file_identifier_pdf: payload.fetch(:cache_file_identifier_pdf),
        cache_filename_pdf: payload.fetch(:cache_filename_pdf)
      )
    end
  end

  protected

  def lock_key_for(arguments)
    work_id = arguments[:work_id]
    pdf_id = arguments[:pdf_file_set_id].presence

    return "derivatives:text_extraction_from_pdf:work:#{work_id}" if pdf_id.blank?

    "derivatives:text_extraction_from_pdf:work:#{work_id}:pdf:#{pdf_id}"
  end
end
