# frozen_string_literal: true

module Hyrax
  class HomepageSerializer
    attr_reader :view_context, :presenter, :featured_work_list, :recent_documents, :featured_researcher

    def initialize(view_context:, presenter:, featured_work_list:, recent_documents:, featured_researcher:)
      @view_context = view_context
      @presenter = presenter
      @featured_work_list = featured_work_list
      @recent_documents = Array(recent_documents)
      @featured_researcher = featured_researcher
    end

    def as_json
      {
        featuredTabLabel: I18n.t('hyrax.homepage.featured_works.tab_label'),
        recentTabLabel: I18n.t('hyrax.homepage.recently_uploaded.tab_label'),
        collectionsTabLabel: I18n.t('hyrax.homepage.admin_sets.title'),
        researcherTabLabel: I18n.t('hyrax.homepage.featured_researcher.tab_label'),
        collectionsLinkLabel: I18n.t('hyrax.homepage.admin_sets.link'),
        noFeaturedWorksText: I18n.t('hyrax.homepage.featured_works.no_works'),
        noRecentWorksText: I18n.t('hyrax.homepage.recently_uploaded.no_public'),
        missingResearcherText: I18n.t('hyrax.homepage.featured_researcher.missing'),
        featuredWorks: serialize_featured_works,
        recentDocuments: serialize_recent_documents,
        collections: serialize_collections,
        collectionsUrl: view_context.main_app.search_catalog_path(f: { generic_type_sim: ['Collection'] }),
        featuredResearcherHtml: featured_researcher&.value.to_s
      }
    end

    private

    def serialize_featured_works
      featured_work_list.featured_works.filter_map do |featured_work|
        work_presenter = featured_work.presenter
        next if work_presenter.blank?

        {
          id: work_presenter.id.to_s,
          title: Array(work_presenter.title).first.to_s,
          url: document_url_for(work_presenter),
          thumbnailUrl: thumbnail_url_for(work_presenter),
          depositor: depositor_for(work_presenter),
          keywords: keyword_links_for(work_presenter)
        }
      end
    end

    def serialize_recent_documents
      recent_documents.map do |document|
        {
          id: document.id.to_s,
          title: document.to_s,
          url: document_url_for(document),
          thumbnailUrl: thumbnail_url_for(document),
          depositor: depositor_for(document),
          keywords: keyword_links_for(document)
        }
      end
    end

    def serialize_collections
      presenter.collections.map do |collection|
        {
          id: collection.id.to_s,
          title: collection_title_for(collection),
          url: document_url_for(collection),
          thumbnailUrl: thumbnail_url_for(collection)
        }
      end
    end

    def depositor_for(resource)
      return '' unless resource.respond_to?(:depositor)

      resource.depositor('')
    end

    def keyword_links_for(resource)
      keywords = Array(resource.respond_to?(:keyword) ? resource.keyword : []).map(&:to_s).reject(&:blank?)
      keywords.first(5).map do |keyword|
        {
          label: keyword,
          url: view_context.main_app.search_catalog_path(f: { keyword_sim: [keyword] })
        }
      end
    end

    def document_url_for(resource)
      document = resource.respond_to?(:solr_document) ? resource.solr_document : resource

      # plain path string first
      path = view_context.search_state.url_for_document(document)
      path.is_a?(String) ? path : view_context.url_for(path)
    rescue StandardError
      '#'
    end

    def thumbnail_url_for(resource)
      if resource.respond_to?(:thumbnail_path) && resource.thumbnail_path.present?
        return resource.thumbnail_path.to_s
      end

      if resource.respond_to?(:solr_document)
        doc = resource.solr_document
        return doc.thumbnail_path.to_s if doc.respond_to?(:thumbnail_path) && doc.thumbnail_path.present?
        return Array(doc['thumbnail_path_ss']).first.to_s if doc.respond_to?(:[])
      end

      Array(resource['thumbnail_path_ss']).first.to_s if resource.respond_to?(:[])
    end

    def collection_title_for(collection)
      if collection.respond_to?(:title_or_label)
        collection.title_or_label.to_s
      elsif collection.respond_to?(:title)
        Array(collection.title).first.to_s
      else
        collection.to_s
      end
    end
  end
end
