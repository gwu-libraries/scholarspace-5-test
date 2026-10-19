# frozen_string_literal: true

class WorkShowPresenter < Hyrax::WorkShowPresenter
  include ::Derivatives::Constants::FileExtensionConstants
  include ::Derivatives::Constants::MimeTypeConstants
  include ::Derivatives::Constants::ThumbnailTagConstants
  include Derivatives::SourceFiles::SourceFileSetMimeDetection
  include StringNormalization

  def list_of_item_ids_to_display
    authorized_item_ids
  end

  def work_show_props(view_context)
    base_props = Rails.cache.fetch(work_show_props_cache_key(view_context)) do
      WorkShowPropsBuilder.new(presenter: self, view_context: view_context).build
    end

    base_props.merge(deepSearch: deep_search_props(view_context))
  end

  def deep_search_props(view_context)
    query = view_context.params[:q].to_s
    { query: query, imageResults: [], pdfResults: [], avResults: [] }
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
    item_members.reject { |member| service_member_presenter?(member) }
  end

  def service_item_members
    all_member_presenters.select { |member| service_member_presenter?(member) }
  end

  def work_show_props_cache_key(view_context)
    modified_date_value = if respond_to?(:solr_document) && solr_document['system_modified_dtsi'].present?
                            solr_document['system_modified_dtsi'].to_s
                          elsif respond_to?(:modified_date)
                            value = send(:modified_date)
                            value.present? ? value.to_s : ''
                          else
                            ''
                          end

    can_edit = safe_can_edit_for_cache_key(view_context)
    can_view_service_files = safe_can_view_service_files_for_cache_key(view_context)

    [id, modified_date_value, can_edit, can_view_service_files].join(':')
  end

  private

  def item_members
    @item_members ||= member_presenters(list_of_item_ids_to_display)
  end

  def service_member_presenter?(member)
    if member.respond_to?(:solr_document)
      return ActiveModel::Type::Boolean.new.cast(member.solr_document['service_file_bsi'])
    end

    source = member.respond_to?(:model) ? member.model : member
    source.respond_to?(:service_file) && ActiveModel::Type::Boolean.new.cast(source.service_file)
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
    return false if service_member_presenter?(member_presenter)

    return true if member_presenter.respond_to?(:audio?) && member_presenter.audio?
    return true if member_presenter.respond_to?(:video?) && member_presenter.video?
    return true if source_av_member_presenter?(member_presenter)

    mime_type = normalize_mime_type(member_presenter.respond_to?(:mime_type) ? member_presenter.mime_type : '')
    mime_type.start_with?(*AUDIO_VISUAL_MIME_PREFIXES)
  end

  def source_av_member_presenter?(member_presenter)
    file_set = member_presenter.respond_to?(:model) ? member_presenter.model : member_presenter
    return false unless file_set.respond_to?(:original_file)

    source_audio_visual_file_set?(file_set)
  rescue StandardError
    false
  end

  def av_member_presenters_in_item_order
    Array(item_members).select { |member_presenter| av_member_presenter?(member_presenter) }
  end

  def transcript_presenters_by_source_id
    derivative_link_resolver.transcripts_by_source_id
  end

  def transcripts_for_source(av_presenter, transcripts_by_source_id)
    transcripts_by_source_id.fetch(av_presenter.id.to_s, [])
  end

  def canvas_index_by_member_id
    manifest_canvas_member_ids
      .each_with_index
      .to_h { |member_id, index| [member_id, index] }
  end

  def manifest_canvas_member_ids
    # Keep transcript canvas ids aligned with the RAMP manifest, which only
    # contains source A/V canvases.
    av_member_presenters_in_item_order.map { |member_presenter| member_presenter.id.to_s }
  end

  def transcript_payload(transcript_presenter, canvas_index)
    {
      id: transcript_presenter.id,
      label: transcript_label(transcript_presenter),
      url: Hyrax::Engine.routes.url_helpers.download_path(id: transcript_presenter.id, locale: nil, format: :vtt),
      format: VTT_MIME_TYPE,
      canvasId: canvas_index
    }
  end

  def derivative_link_resolver
    @derivative_link_resolver ||= Resolvers::DerivativeLinkResolver.new(members: all_member_presenters)
  end

  def all_member_presenters
    @all_member_presenters ||= begin
      ids = respond_to?(:member_ids) ? Array(member_ids).map(&:to_s) : []
      presenters = ids.present? ? Array(member_presenters(ids)) : Array(member_presenters)
      presenters.compact
    end
  end

  def safe_can_edit_for_cache_key(view_context)
    view_context.can?(:edit, self)
  rescue StandardError
    false
  end

  def safe_can_view_service_files_for_cache_key(view_context)
    WorkShowPropsBuilder.can_view_service_files?(view_context)
  rescue StandardError
    false
  end
end
