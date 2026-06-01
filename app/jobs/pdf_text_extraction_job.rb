# frozen_string_literal: true

class PdfTextExtractionJob < ApplicationJob
  queue_as :derivatives_pdf_text_extraction

  def perform(work_id:, pdf_file_set_id: nil, file_set_id: nil)
    work = Hyrax.query_service.find_by(id: work_id)
    return unless work

    service = DerivativesServices::PdfTextExtractionService.new(work)
    target_pdf_file_set_id = pdf_file_set_id.presence || file_set_id

    if target_pdf_file_set_id.present?
      service.process_file_set(pdf_file_set_id: target_pdf_file_set_id)
      return
    end

    service.pdf_file_set_ids_needing_extraction.each do |pending_file_set_id|
      self.class.perform_later(work_id: work.id.to_s, pdf_file_set_id: pending_file_set_id)
    end
  end
end
