# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource Page`
class DerivedPage < Hyrax::Work
  include Hyrax.Schema(:basic_metadata)
  include Hyrax.Schema(:derived_page)
end
