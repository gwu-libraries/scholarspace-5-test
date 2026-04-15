Rails.application.config.to_prepare do
  Hyrax::FileSetPresenter.class_eval do
    def alt_text_for_view
      solr_document.alt_text_for_view
    end
  end
end