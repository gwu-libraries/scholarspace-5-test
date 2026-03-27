Rails.application.config.to_prepare do
  Hyrax::WorkShowPresenter.class_eval do

    def work_show_props(view_context)
      Hyrax::WorkShowSerializer.new(presenter: self, view_context: view_context).as_json
    end

    def transcript_files
      Array(member_presenters).filter_map do |member_presenter|
        next unless transcript_presenter?(member_presenter)

        {
          id: member_presenter.id,
          label: transcript_label(member_presenter),
          url: Hyrax::Engine.routes.url_helpers.download_path(id: member_presenter.id, locale: nil),
          format: 'text/vtt'
        }
      end
    end

    def original_item_members
      item_members.reject { |member| derivative_member_presenter?(member) }
    end

    def service_item_members
      # Use all member_presenters (unpaginated) so every service file appears
      # regardless of pagination state, since service files can be added after
      # the original members and would otherwise be cut off.
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

    def transcript_presenter?(member_presenter)
      return false unless member_presenter.respond_to?(:file_set?) && member_presenter.file_set?

      transcript_filename(member_presenter).downcase.end_with?('_vtt.vtt')
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