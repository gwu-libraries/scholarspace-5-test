# frozen_string_literal: true
module HyraxHelper
  include ::BlacklightHelper
  include Hyrax::BlacklightOverride
  include Hyrax::HyraxHelperBehavior

  def render_ocr_snippets(options = {})
    values = Array.wrap(options[:value]).select(&:html_safe?)
    return ''.html_safe if values.blank?

    safe_join(values.map { |value| tag.span(sanitize(value.to_s), class: 'ocr-snippet') }, tag.br)
  end
end
