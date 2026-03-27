Rails.application.config.to_prepare do
  module Hyrax
    module IiifManifestDisplayImagePresenterHocrDecorator
      def annotation_content
        Array(super) + hocr_annotation_content
      end

      private

      def hocr_annotation_content
        return [] unless respond_to?(:iiif_parent_presenter, true)

        hocr_presenter = matching_hocr_presenter
        return [] unless hocr_presenter

        [hocr_annotation(hocr_presenter)]
      end

      def hocr_annotation(hocr_presenter)
        IIIFManifest::V3::AnnotationContent.new(
          type: 'Text',
          motivation: 'supplementing',
          body_id: Hyrax::Engine.routes.url_helpers.download_url(hocr_presenter.id, host: hostname),
          format: 'text/vnd.hocr+html',
          label: hocr_label(hocr_presenter)
        )
      end

      def matching_hocr_presenter
        expected = expected_hocr_filename
        return nil if expected.blank?

        iiif_parent_presenter.member_presenters.find do |presenter|
          next false unless presenter.respond_to?(:file_set?) && presenter.file_set?

          presenter_filename(presenter).casecmp(expected).zero?
        end
      end

      def expected_hocr_filename
        return nil unless model.respond_to?(:original_file)

        original_filename = model.original_file&.original_filename.to_s
        return nil if original_filename.blank?

        "#{File.basename(original_filename, File.extname(original_filename))}_HOCR.hocr"
      end

      def presenter_filename(presenter)
        return presenter.label.to_s if presenter.respond_to?(:label) && presenter.label.present?
        return presenter.title.to_a.first.to_s if presenter.respond_to?(:title) && presenter.title.present?

        ''
      end

      def hocr_label(presenter)
        label = presenter_filename(presenter)
        label.present? ? label : 'OCR'
      end
    end
  end

  Hyrax::IiifManifestPresenter::DisplayImagePresenter.prepend Hyrax::IiifManifestDisplayImagePresenterHocrDecorator
end