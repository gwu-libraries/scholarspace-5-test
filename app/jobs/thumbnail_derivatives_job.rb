# frozen_string_literal: true

class ThumbnailDerivativesJob < ApplicationJob
  queue_as :derivatives_thumbnail

  def perform(work_id:)
    work = Hyrax.query_service.find_by(id: work_id)
    return unless work

    ScholarspaceDerivativesServices::ThumbnailDerivativesService.new(work).call
  end
end
