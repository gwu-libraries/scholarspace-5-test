# frozen_string_literal: true

class CatalogSearchBuilder < Hyrax::CatalogSearchBuilder
  include BlacklightRangeLimit::RangeLimitBuilder
end
