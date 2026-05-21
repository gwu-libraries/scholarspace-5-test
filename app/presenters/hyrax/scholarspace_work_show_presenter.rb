# frozen_string_literal: true

module Hyrax
  class ScholarspaceWorkShowPresenter < WorkShowPresenter
    include StringNormalization
    def work_show_props(view_context)
      WorkShowSerializer.new(presenter: self, view_context: view_context).as_json
    end

    def transcript_files
      av_presenters = av_member_presenters_in_item_order
      transcripts_by_source_id = transcript_presenters_by_source_id
      canvas_indexes = canvas_index_by_member_id

      av_presenters.flat_map do |av_presenter|
        canvas_index = canvas_indexes[av_presenter.id.to_s]
        next [] if canvas_index.nil?

        transcripts_for_source(av_presenter, transcripts_by_source_id).map do |transcript_presenter|
          transcript_payload(transcript_presenter, canvas_index)
        end
      end
    end

    def canvas_index_for_member(member_id)
      canvas_index_by_member_id[member_id.to_s]
    end

    def original_item_members
      item_members.reject { |member| derivative_member_presenter?(member) }
    end

    def service_item_members
      all_member_presenters.select { |member| derivative_member_presenter?(member) }
    end

    def items_tab_id_prefix
      "work-items-tabs-#{id}"
    end

    private

    def item_members
      @item_members ||= member_presenters(list_of_item_ids_to_display)
    end

    def derivative_member_presenter?(member)
      member.respond_to?(:solr_document) && member.solr_document['service_file_bsi']
    end

    def transcript_label(member_presenter)
      label = transcript_filename(member_presenter)
      label.present? ? label : 'Transcript'
    end

    def transcript_filename(member_presenter)
      return member_presenter.label.to_s if member_presenter.respond_to?(:label) && member_presenter.label.present?
      return member_presenter.title.to_a.first.to_s if member_presenter.respond_to?(:title) && member_presenter.title.present?

      ''
    end

    def av_member_presenter?(member_presenter)
      return false if derivative_member_presenter?(member_presenter)

      return true if member_presenter.respond_to?(:audio?) && member_presenter.audio?
      return true if member_presenter.respond_to?(:video?) && member_presenter.video?

      mime_type = normalize_mime_type(member_presenter.respond_to?(:mime_type) ? member_presenter.mime_type : '')
      mime_type.start_with?('audio/', 'video/')
    end

    def transcript_member_presenters
      all_member_presenters.select do |member_presenter|
        transcript_filename(member_presenter).downcase.end_with?('.vtt') && transcript_source_file_set_id(member_presenter).present?
      end
    end

    def av_member_presenters_in_item_order
      Array(item_members).select { |member_presenter| av_member_presenter?(member_presenter) }
    end

    def transcript_presenters_by_source_id
      transcript_member_presenters.group_by do |transcript_presenter|
        transcript_source_file_set_id(transcript_presenter)
      end
    end

    def transcripts_for_source(av_presenter, transcripts_by_source_id)
      transcripts_by_source_id.fetch(av_presenter.id.to_s, [])
    end

    def canvas_index_by_member_id
      manifest_canvas_member_presenters
        .each_with_index
        .to_h { |member_presenter, index| [member_presenter.id.to_s, index] }
    end

    def manifest_canvas_member_presenters
      original_item_members.select do |member_presenter|
        av_member_presenter?(member_presenter) || image_member_presenter?(member_presenter)
      end
    end

    def image_member_presenter?(member_presenter)
      return false if derivative_member_presenter?(member_presenter)

      mime_type = normalize_mime_type(member_presenter.respond_to?(:mime_type) ? member_presenter.mime_type : '')
      return true if mime_type.start_with?('image/')

      filename = if member_presenter.respond_to?(:label) && member_presenter.label.present?
                   member_presenter.label.to_s
                 elsif member_presenter.respond_to?(:title) && member_presenter.title.present?
                   member_presenter.title.to_a.first.to_s
                 else
                   ''
                 end

      extension = File.extname(filename).downcase
      %w[.jpg .jpeg .png .gif .tif .tiff .webp .jp2].include?(extension)
    end

    def transcript_source_file_set_id(transcript_presenter)
      entry = related_url_candidates(transcript_presenter)
              .find { |value| value.start_with?('source_file_set_id:') }
      entry.to_s.sub('source_file_set_id:', '')
    end

    def transcript_payload(transcript_presenter, canvas_index)
      {
        id: transcript_presenter.id,
        label: transcript_label(transcript_presenter),
        url: Hyrax::Engine.routes.url_helpers.download_path(id: transcript_presenter.id, locale: nil, format: :vtt),
        format: 'text/vtt',
        canvasId: canvas_index
      }
    end

    def related_url_candidates(member_presenter)
      source = member_presenter.respond_to?(:model) ? member_presenter.model : member_presenter
      candidates = []
      candidates.concat(Array(source.related_url)) if source.respond_to?(:related_url)

      if member_presenter.respond_to?(:solr_document)
        candidates.concat(Array(member_presenter.solr_document['related_url_tesim']))
      end

      candidates.map(&:to_s)
    end

    def all_member_presenters
      @all_member_presenters ||= Array(member_presenters)
    end
  end
end
