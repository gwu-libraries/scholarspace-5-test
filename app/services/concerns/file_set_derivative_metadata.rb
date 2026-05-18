# frozen_string_literal: true

module FileSetDerivativeMetadata
  extend ActiveSupport::Concern
  include PersistenceAdapter

  # Get all tags (metadata entries) for a file set
  def tags_for_file_set(file_set)
    Array(file_set.respond_to?(:related_url) ? file_set.related_url : []).map(&:to_s)
  end

  # Extract source_file_set_id tag value from file set tags
  def source_file_set_id_tag_for(file_set)
    extract_source_file_set_id(tags_for_file_set(file_set))
  end

  # Extract source_file_set_id value from arbitrary related_url-style values
  def extract_source_file_set_id(values)
    entry = Array(values).map(&:to_s).find { |value| value.start_with?('source_file_set_id:') }
    entry.to_s.sub('source_file_set_id:', '')
  end

  # Add a tag to file set's related_url field
  def add_tag_to_file_set(file_set, tag)
    return file_set unless file_set.respond_to?(:related_url=)

    existing_tags = tags_for_file_set(file_set)
    return file_set if existing_tags.include?(tag)

    file_set.related_url = (existing_tags + [tag]).uniq
    save_file_set(file_set)
  end

  # Remove a tag from file set's related_url field
  def remove_tag_from_file_set(file_set, tag)
    return file_set unless file_set.respond_to?(:related_url=)

    existing_tags = tags_for_file_set(file_set)
    return file_set unless existing_tags.include?(tag)

    new_tags = existing_tags - [tag]
    file_set.related_url = new_tags
    save_file_set(file_set)
  end

  # Add source_file_set_id tag to track which file set generated this derivative
  def tag_source_file_set(file_set, source_file_set_id)
    tag = "source_file_set_id:#{source_file_set_id}"
    add_tag_to_file_set(file_set, tag)
  end

  # Add derivative_type tag to identify derivative purpose (thumbnail, hocr, vtt, etc)
  def tag_derivative_type(file_set, derivative_type)
    tag = "derivative_type:#{derivative_type}"
    add_tag_to_file_set(file_set, tag)
  end

  # Save file set and update index
  def save_file_set(file_set)
    save_and_index(file_set)
  end
end
