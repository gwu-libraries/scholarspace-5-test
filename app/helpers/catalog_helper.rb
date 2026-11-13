# frozen_string_literal: true

module CatalogHelper
  def render_catalog_description(options = {})
    values = Array.wrap(options[:value]).map do |value|
      words = strip_tags(value.to_s).squish.split
      next words.join(' ') if words.length <= 20

      "#{words.first(20).join(' ')}..."
    end

    iconify_auto_link(options.merge(value: values))
  end
end
