# frozen_string_literal: true

module Hyrax
  
  # this class provides a custom IIIF manifest builder that wraps the work presenter to add support for including transcript and HOCR annotations on AV files in the manifest. It is intended to be used with the ScholarspaceWorkShowPresenter which provides the necessary member_presenters and file_set_presenters methods.

  class ScholarspaceIiifManifestBuilder
    class WorkPresenterWrapper < SimpleDelegator
      def search_service
        return nil if id.blank?

        Rails.application.routes.url_helpers.solr_document_iiif_search_url(
          solr_document_id: id,
          host: hostname
        )
      end

      def member_presenters
        @member_presenters_cache ||= __getobj__.member_presenters.map do |presenter|
          FileSetPresenterWrapper.new(presenter, self)
        end
      end

      def file_set_presenters
        member_presenters.select { |p| p.file_set? && (p.display_image || p.display_content) }
      end
    end

    class FileSetPresenterWrapper < SimpleDelegator
      def initialize(presenter, work_presenter)
        super(presenter)
        @work_presenter = work_presenter
      end

      def annotation_content
        Array(transcript_annotation_content) + Array(hocr_annotation_content)
      end

      private

      def transcript_annotation_content
        return [] unless av_canvas?

        transcript_sibling_presenters.map do |transcript|
          IIIFManifest::V3::AnnotationContent.new(
            type: 'Text',
            motivation: 'supplementing',
            body_id: Hyrax::Engine.routes.url_helpers.download_url(transcript.id, host: hostname),
            format: 'text/vtt',
            label: presenter_filename(transcript).presence || 'Transcript'
          )
        end
      end

      def av_canvas?
        return true if respond_to?(:audio?) && audio?
        return true if respond_to?(:video?) && video?

        mime = respond_to?(:mime_type) ? mime_type.to_s.downcase : ''
        mime.start_with?('audio/') || mime.start_with?('video/')
      end

      def transcript_sibling_presenters
        @work_presenter.member_presenters.select do |sibling|
          next false unless sibling.respond_to?(:file_set?) && sibling.file_set?
          next false if sibling.equal?(self)

          presenter_filename(sibling).downcase.end_with?('_vtt.vtt')
        end
      end

      def hocr_annotation_content
        hocr = matching_hocr_sibling_presenter
        return [] unless hocr

        [
          IIIFManifest::V3::AnnotationContent.new(
            type: 'Text',
            motivation: 'supplementing',
            body_id: Hyrax::Engine.routes.url_helpers.download_url(hocr.id, host: hostname),
            format: 'text/vnd.hocr+html',
            label: presenter_filename(hocr).presence || 'OCR'
          )
        ]
      end

      def matching_hocr_sibling_presenter
        expected = expected_hocr_filename
        return nil if expected.blank?

        @work_presenter.member_presenters.find do |sibling|
          next false unless sibling.respond_to?(:file_set?) && sibling.file_set?
          next false if sibling.equal?(self)

          presenter_filename(sibling).casecmp(expected).zero?
        end
      end

      def expected_hocr_filename
        source = respond_to?(:model) ? model : nil
        return nil unless source.respond_to?(:original_file)

        original_filename = source.original_file&.original_filename.to_s
        return nil if original_filename.blank?

        "#{File.basename(original_filename, File.extname(original_filename))}_HOCR.hocr"
      end

      def presenter_filename(presenter)
        return presenter.label.to_s if presenter.respond_to?(:label) && presenter.label.present?
        return presenter.title.to_a.first.to_s if presenter.respond_to?(:title) && presenter.title.present?

        ''
      end
    end

    def self.manifest_for(presenter:)
      new.manifest_for(presenter: presenter)
    end

    def manifest_for(presenter:)
      wrapped = WorkPresenterWrapper.new(presenter)
      factory = manifest_factory_for(presenter)
      Hyrax::ManifestBuilderService.new(iiif_manifest_factory: factory)
                                   .manifest_for(presenter: wrapped)
    end

    private

    def manifest_factory_for(presenter)
      file_sets = Array(presenter.respond_to?(:file_set_presenters) ? presenter.file_set_presenters : [])
      av = Flipflop.iiif_av? && file_sets.any? { |p| p.video? || p.audio? }
      pdf = Flipflop.iiif_pdf? && file_sets.any?(&:pdf?)
      (av || pdf) ? IIIFManifest::V3::ManifestFactory : Hyrax.config.iiif_manifest_factory
    end
  end
end
