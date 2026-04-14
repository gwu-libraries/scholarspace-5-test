# frozen_string_literal: true

module Hyrax
  class ScholarspaceWorkShowPresenter < WorkShowPresenter
    def work_show_props(view_context)
      WorkShowSerializer.new(presenter: self, view_context: view_context).as_json
    end

    def transcript_files
      Array(member_presenters).filter_map do |member_presenter|
        next unless derivative_member_presenter?(member_presenter)
        next unless transcript_filename(member_presenter).downcase.end_with?('.vtt')

        {
          id: member_presenter.id,
          label: transcript_label(member_presenter),
          url: Hyrax::Engine.routes.url_helpers.download_path(id: member_presenter.id, locale: nil, format: :vtt),
          format: 'text/vtt'
        }
      end
    end

    def original_item_members
      item_members.reject { |member| derivative_member_presenter?(member) }
    end

    def service_item_members
      Array(member_presenters).select { |member| derivative_member_presenter?(member) }
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
  end
end
