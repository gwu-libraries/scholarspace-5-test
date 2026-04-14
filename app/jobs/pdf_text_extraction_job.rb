# frozen_string_literal: true

class PdfTextExtractionJob < ApplicationJob
  queue_as :derivatives_pdf_text_extraction

  def perform(work_id:)
    work = Hyrax.query_service.find_by(id: work_id)
    return unless work

    ScholarspaceDerivativesServices::PdfTextExtractionService.new(work).call
  end
end
