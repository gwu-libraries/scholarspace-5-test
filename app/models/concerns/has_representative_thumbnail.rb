# frozen_string_literal: true

module HasRepresentativeThumbnail
  extend ActiveSupport::Concern

  def thumbnail_url
    Resolvers::ThumbnailResolver.new.representative_thumbnail_path_for_work(work: self)
  rescue StandardError
    nil
  end
end
