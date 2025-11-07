# frozen_string_literal: true

module WorkShowPresenterDecorator
  def show_split_button?
    return parent.try(:split_pdfs?) if parent.respond_to?(:split_pdfs?)
    true
  end

  # this is not working correctly
  # file_type_and_permissions_valid? returns false, not rendering iiif
  # overriding to return true as temp fix
  def members_include_viewable_image?
    all_member_ids = load_file_set_ids(solr_document)
    Array
      .wrap(all_member_ids)
      .each do |id|
        # maybe need to do a .any? situation, since first one is going to be a pdf and not image
        return true if file_type_and_permissions_valid?(member_presenters.first)
      end
    # false
    true
  end
end

Hyrax::WorkShowPresenter.prepend(WorkShowPresenterDecorator)
