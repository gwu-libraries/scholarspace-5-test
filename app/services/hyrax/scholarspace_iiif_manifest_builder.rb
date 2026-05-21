# frozen_string_literal: true

module Hyrax
  class ScholarspaceIiifManifestBuilder
    include StringNormalization

    class WorkPresenterWrapper < SimpleDelegator
      include StringNormalization

      def sequence_rendering
        source_rendering = Array(work_presenter.respond_to?(:sequence_rendering) ? work_presenter.sequence_rendering : [])
        return source_rendering if source_rendering.empty?

        disallowed_ids = text_annotation_body_ids
        return source_rendering if disallowed_ids.empty?

        source_rendering.reject do |entry|
          rendering_entry_id(entry).in?(disallowed_ids)
        end
      end

      def search_service
        return nil if id.blank?

        Rails.application.routes.url_helpers.solr_document_iiif_search_url(
          solr_document_id: id,
          host: hostname
        )
      end

      def member_presenters
        @member_presenters_cache ||= begin
          source_presenters = Array(work_presenter.member_presenters)
          representative_id = work_presenter.respond_to?(:representative_id) ? work_presenter.representative_id.to_s : ''

          if representative_id.present?
            source_presenters = source_presenters.sort_by do |presenter|
              presenter.id.to_s == representative_id ? 0 : 1
            end
          end

          source_presenters.map do |presenter|
            FileSetPresenterWrapper.new(presenter, self)
          end
        end
      end

      def file_set_presenters
        member_presenters.select do |p|
          next false unless displayable_file_set?(p)
          next false if representative_thumbnail?(p)

          true
        end
      end

      private

      def text_annotation_body_ids
        @text_annotation_body_ids ||= member_presenters.flat_map do |member|
          next [] unless member.respond_to?(:annotation_content)

          Array(member.annotation_content).filter_map do |content|
            if content.respond_to?(:body_id)
              content.body_id.to_s
            elsif content.respond_to?(:id)
              content.id.to_s
            elsif content.respond_to?(:to_h)
              payload = content.to_h
              payload[:body_id] || payload['body_id'] || payload[:id] || payload['id']
            end
          end
        end.map(&:to_s).reject(&:blank?).uniq
      end

      def rendering_entry_id(entry)
        if entry.respond_to?(:id)
          entry.id.to_s
        elsif entry.respond_to?(:to_h)
          payload = entry.to_h
          (payload[:id] || payload['id'] || payload[:'@id'] || payload['@id']).to_s
        elsif entry.is_a?(Hash)
          (entry[:id] || entry['id'] || entry[:'@id'] || entry['@id']).to_s
        else
          ''
        end
      end

      def representative_thumbnail?(presenter)
        return false unless work_presenter.respond_to?(:thumbnail_id) && work_presenter.thumbnail_id.present?
        return false unless presenter.id.to_s == work_presenter.thumbnail_id.to_s

        thumbnail_service_file_set?(presenter)
      end

      def work_presenter
        __getobj__
      end

      def displayable_file_set?(presenter)
        presenter.file_set? && (presenter.display_image || presenter.display_content)
      end

      def thumbnail_service_file_set?(presenter)
        source = presenter.respond_to?(:model) ? presenter.model : presenter

        service_file = if source.respond_to?(:service_file)
                         source.service_file
                       elsif presenter.respond_to?(:solr_document)
                         presenter.solr_document['service_file_bsi']
                       end
        return false unless ActiveModel::Type::Boolean.new.cast(service_file)

        tags = if source.respond_to?(:related_url)
                 Array(source.related_url).map(&:to_s)
               elsif presenter.respond_to?(:solr_document)
                 Array(presenter.solr_document['related_url_tesim']).map(&:to_s)
               else
                 []
               end

        tags.include?('derivative_type:thumbnail')
      end

    end

    class FileSetPresenterWrapper < SimpleDelegator
      include StringNormalization

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

        mime = normalize_mime_type(respond_to?(:mime_type) ? mime_type : '')
        mime.start_with?('audio/') || mime.start_with?('video/')
      end

      def transcript_sibling_presenters
        source_id = id.to_s
        transcript_file_set_siblings.select do |sibling|
          transcript_source_file_set_id(sibling) == source_id
        end
      end

      def transcript_file_set_siblings
        sibling_file_sets.select do |sibling|
          normalize_filename(presenter_filename(sibling)).end_with?('.vtt')
        end
      end

      def sibling_file_sets
        @work_presenter.member_presenters.select do |sibling|
          sibling.respond_to?(:file_set?) && sibling.file_set? && !sibling.equal?(self)
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
        source_id = id.to_s
        @work_presenter.member_presenters.find do |sibling|
          next false unless sibling.respond_to?(:file_set?) && sibling.file_set?
          next false if sibling.equal?(self)

          source_file_set_id_for(sibling) == source_id
        end
      end

      def presenter_filename(presenter)
        source = presenter.respond_to?(:model) ? presenter.model : presenter
        if source.respond_to?(:original_file)
          original_filename = source.original_file&.original_filename.to_s
          return original_filename if original_filename.present?
        end

        return presenter.label.to_s if presenter.respond_to?(:label) && presenter.label.present?
        return presenter.title.to_a.first.to_s if presenter.respond_to?(:title) && presenter.title.present?

        ''
      end

      def source_file_set_id_for(presenter)
        entry = related_url_candidates_for(presenter)
                .find { |value| value.start_with?('source_file_set_id:') }
        entry.to_s.sub('source_file_set_id:', '')
      end

      def transcript_source_file_set_id(transcript_presenter)
        source_file_set_id_for(transcript_presenter)
      end

      def related_url_candidates_for(presenter)
        source = presenter.respond_to?(:model) ? presenter.model : presenter
        candidates = []
        candidates.concat(Array(source.related_url)) if source.respond_to?(:related_url)

        if presenter.respond_to?(:solr_document)
          candidates.concat(Array(presenter.solr_document['related_url_tesim']))
        end

        candidates.map(&:to_s)
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
