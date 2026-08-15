# frozen_string_literal: true

class DerivativeJobs::FileSetLevel::TextExtraction::FromPdfPersistJob < ApplicationJob
  include JobDistributedLock
  include LockRetryProfiles::ShortBackoff

  queue_as :derivatives_text_extraction_from_pdf_persist

  def perform(work_id:, source_file_set_id:, cache_file_identifier_hocr:, cache_filename_hocr:, cache_file_identifier_pdf:, cache_filename_pdf:)
    Rails.logger.info(
      "derivative_pipeline event=pdf_text_persist_start work_id=#{work_id} " \
      "source_file_set_id=#{source_file_set_id} job_id=#{job_id} queue=#{queue_name}"
    )

    with_work(work_id: work_id) do |work|
      Derivatives::FileSetLevel::TextExtraction::FromPdf
        .new(work)
        .persist_from_cache(
          source_file_set_id: source_file_set_id,
          cache_file_identifier_hocr: cache_file_identifier_hocr,
          cache_filename_hocr: cache_filename_hocr,
          cache_file_identifier_pdf: cache_file_identifier_pdf,
          cache_filename_pdf: cache_filename_pdf
        )
    end
  end

  protected

  def lock_key_for(arguments)
    source_file_set_id = arguments[:source_file_set_id].to_s
    "derivatives:text_extraction_from_pdf:work:#{arguments[:work_id]}:source:#{source_file_set_id}:persist"
  end
end
