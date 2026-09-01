# frozen_string_literal: true

module HyraxFileSetPresenterAltTextDecorator
  def alt_text_for_view
    return solr_document.alt_text_for_view if solr_document.respond_to?(:alt_text_for_view)

    indexed_value('alt_text_tesim').presence || indexed_value('title_tesim')
  end

  private

  def indexed_value(field_name)
    return unless solr_document.respond_to?(:[])

    Array(solr_document[field_name]).first
  end
end

Rails.application.config.to_prepare do
  Hyrax::FileSetPresenter.prepend HyraxFileSetPresenterAltTextDecorator unless Hyrax::FileSetPresenter < HyraxFileSetPresenterAltTextDecorator
end