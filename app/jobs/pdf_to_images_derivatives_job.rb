# frozen_string_literal: true

class PdfToImagesDerivativesJob < ApplicationJob
  queue_as :derivatives_pdf_to_images

  def perform(work_id:)
    work = Hyrax.query_service.find_by(id: work_id)
    return unless work

    DerivativesServices::PdfToImagesDerivativesService.new(work).call
  end
end
