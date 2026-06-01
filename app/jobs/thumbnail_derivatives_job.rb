# frozen_string_literal: true

class ThumbnailDerivativesJob < ApplicationJob
  queue_as :derivatives_thumbnail

  def perform(work_id:)
    with_work(work_id: work_id) { |work| DerivativesServices::ThumbnailDerivativesService.new(work).call }
  end
end
