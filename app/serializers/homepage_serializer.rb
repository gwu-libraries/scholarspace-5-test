# frozen_string_literal: true

class HomepageSerializer

  # this is used to serialize data for the homepage React component.
  
  attr_reader :view_context, :recent_documents, :collections

  def initialize(view_context:, recent_documents:, collections:)
    @view_context = view_context
    @recent_documents = Array(recent_documents)
    @collections = Array(collections)
  end

  def as_json
    {
      recentWorksTitle: I18n.t('hyrax.homepage.recently_uploaded.title'),
      featuredCollectionsTitle: I18n.t('hyrax.homepage.admin_sets.title'),
      collectionsLinkLabel: I18n.t('hyrax.homepage.admin_sets.link'),
      noRecentWorksText: I18n.t('hyrax.homepage.recently_uploaded.no_public'),
      recentDocuments: recent_documents_payload,
      collections: collections_payload,
      collectionsUrl: collections_url
    }
  end

  private

  def recent_documents_payload
    recent_documents.map do |document|
      {
        id: document.id.to_s,
        title: document.to_s,
        url: record_url(document, namespace: :main_app),
        thumbnailUrl: thumbnail_for_document(document),
        depositor: depositor_value(document, 'hyrax.homepage.recently_uploaded.document.depositor_missing'),
        keywords: keyword_links(Array(document.keyword))
      }
    end
  end

  def collections_payload
    collections.map do |collection|
      {
        id: collection.id.to_s,
        title: collection_title(collection),
        url: record_url(collection, namespace: :hyrax),
        thumbnailUrl: thumbnail_for_document(collection)
      }
    end
  end

  def collection_title(collection)
    return collection.title_or_label.to_s if collection.respond_to?(:title_or_label)

    collection.to_s
  end

  def collections_url
    Rails.application.routes.url_helpers.search_catalog_path(
      f: { generic_type_sim: ['Collection'] }
    )
  end

  def depositor_value(record, missing_key)
    fallback = I18n.t(missing_key)
    return fallback unless record.respond_to?(:depositor)

    record.depositor(fallback).to_s
  rescue StandardError
    fallback
  end

  def keyword_links(keywords)
    keywords.filter_map do |keyword|
      label = keyword.to_s.strip
      next if label.blank?

      {
        label: label,
        url: Rails.application.routes.url_helpers.search_catalog_path(
          f: { keyword_sim: [label] }
        )
      }
    end
  end

  def thumbnail_for_document(document)
    html = view_context
      .document_presenter(document)
      &.thumbnail
      &.thumbnail_tag({ width: 90, alt: '' }, { suppress_link: true })

    image_src_from_html(html.to_s)
  rescue StandardError
    nil
  end

  def image_src_from_html(html)
    match = html.match(/src=(['\"])(.*?)\1/)
    match && match[2].presence
  end

  def record_url(record, namespace:)
    routes_proxy = namespace == :hyrax ? view_context.hyrax : view_context.main_app
    view_context.url_for([routes_proxy, record])
  rescue StandardError
    '#'
  end
end
