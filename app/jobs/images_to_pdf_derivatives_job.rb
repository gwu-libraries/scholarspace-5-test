# frozen_string_literal: true

class ImagesToPdfDerivativesJob < ApplicationJob
  queue_as :derivatives_images_to_pdf

  def perform(work_id:)
    work = Hyrax.query_service.find_by(id: work_id)
    return unless work

    ScholarspaceDerivativesServices::ImagesToPdfDerivativesService.new(work).call
    PdfTextExtractionJob.perform_later(work_id: work.id.to_s)
  end
end
