# frozen_string_literal: true

module HasRepresentativeThumbnail
  extend ActiveSupport::Concern

  def thumbnail_url
    id = thumbnail_id
    return nil if id.blank?

    Hyrax::Engine.routes.url_helpers.download_path(id: id, locale: nil)
  rescue StandardError
    nil
  end
end
