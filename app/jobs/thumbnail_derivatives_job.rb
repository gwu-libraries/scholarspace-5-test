# frozen_string_literal: true

class ThumbnailDerivativesJob < ApplicationJob
  queue_as :thumbnail

  def perform(work_id:)
    with_work(work_id: work_id) { |work| Derivatives::Thumbnail.new(work).call }
  end
end
