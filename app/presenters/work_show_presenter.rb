# frozen_string_literal: true

class WorkShowPresenter < Hyrax::WorkShowPresenter
  def list_of_item_ids_to_display
    authorized_item_ids
  end

  def work_show_props(view_context)
    WorkShowSerializer.new(presenter: self, view_context: view_context).as_json
  end

  def original_item_members
    item_members.reject { |member| service_member_presenter?(member) }
  end

  def service_item_members
    all_member_presenters.select { |member| service_member_presenter?(member) }
  end

  private

  def item_members
    @item_members ||= member_presenters(list_of_item_ids_to_display)
  end

  def all_member_presenters
    @all_member_presenters ||= begin
      ids = respond_to?(:member_ids) ? Array(member_ids).map(&:to_s) : []
      presenters = ids.present? ? Array(member_presenters(ids)) : Array(member_presenters)
      presenters.compact
    end
  end

  def service_member_presenter?(member)
    if member.respond_to?(:solr_document)
      return ActiveModel::Type::Boolean.new.cast(member.solr_document['service_file_bsi'])
    end

    source = member.respond_to?(:model) ? member.model : member
    source.respond_to?(:service_file) && ActiveModel::Type::Boolean.new.cast(source.service_file)
  end

end