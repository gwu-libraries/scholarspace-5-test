# frozen_string_literal: true

class PdfHocrEmbeddingJob < ApplicationJob
  queue_as :derivatives_pdf_hocr_embedding

  def perform(work_id:, hocr_file_set_id:)
    work = Hyrax.query_service.find_by(id: work_id)
    return unless work

    hocr_file_set = Hyrax.query_service.find_by(id: hocr_file_set_id)
    return unless hocr_file_set

    ScholarspaceDerivativesServices::PdfHocrEmbeddingService.new(
      work: work,
      hocr_file_set: hocr_file_set
    ).call
  end
end
