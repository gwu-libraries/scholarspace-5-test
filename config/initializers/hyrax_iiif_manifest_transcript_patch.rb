Rails.application.config.to_prepare do
  module Hyrax
    module IiifManifestPresenterDecorator

      def member_presenters
        presenters = Array(super)

        presenters.each do |presenter|
          presenter.instance_variable_set(:@iiif_parent_presenter, self)
        end

        presenters
      end

      private

      def search_service
        return if id.blank?

        Rails.application.routes.url_helpers.solr_document_iiif_search_url(
          solr_document_id: id,
          host: hostname
        )
      end
    end

    module IiifManifestDisplayImagePresenterDecorator
      def annotation_content
        return [] unless av_canvas?
        return [] unless iiif_parent_presenter

        transcript_presenters.map do |transcript|
          IIIFManifest::V3::AnnotationContent.new(
            type: 'Text',
            motivation: 'supplementing',
            body_id: Hyrax::Engine.routes.url_helpers.download_url(transcript.id, host: hostname),
            format: 'text/vtt',
            label: transcript_label(transcript)
          )
        end
      end

      private

      def iiif_parent_presenter
        @iiif_parent_presenter
      end

      def av_canvas?
        return true if model.respond_to?(:audio?) && model.audio?
        return true if model.respond_to?(:video?) && model.video?

        mime = model.respond_to?(:mime_type) ? model.mime_type.to_s.downcase : ''
        mime.start_with?('audio/') || mime.start_with?('video/')
      end

      def transcript_presenters
        iiif_parent_presenter.member_presenters.select { |presenter| transcript_presenter?(presenter) }
      end

      def transcript_presenter?(presenter)
        return false unless presenter.respond_to?(:file_set?) && presenter.file_set?

        transcript_filename(presenter).downcase.end_with?('_vtt.vtt')
      end

      def transcript_filename(presenter)
        return presenter.label.to_s if presenter.respond_to?(:label) && presenter.label.present?
        return presenter.title.to_s if presenter.respond_to?(:title) && presenter.title.present?

        ''
      end

      def transcript_label(presenter)
        label = transcript_filename(presenter)
        label.present? ? label : 'Transcript'
      end
    end
  end

  Hyrax::IiifManifestPresenter.prepend Hyrax::IiifManifestPresenterDecorator
  Hyrax::IiifManifestPresenter::DisplayImagePresenter.prepend Hyrax::IiifManifestDisplayImagePresenterDecorator
end