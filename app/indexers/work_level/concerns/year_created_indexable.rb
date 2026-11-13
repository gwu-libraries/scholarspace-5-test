# frozen_string_literal: true

module YearCreatedIndexable
  # parses date created fields into sortable datetimes
  # "date created" is an array of free-text entries. 
  # Why there can be multiple date_createds and why they are
  # strings is a mystery. 

  # This parses all of the entries for date_created, looks for
  # 4 digit strings, assumes they are year, returns earliest

  def to_solr
    super.tap do |index_document|
      if resource.respond_to?(:date_created) && resource.date_created.present?
        index_document[:year_created_isim] = parse_year(resource.date_created)
      end
    end
  end

  def parse_year(ambiguous_date_string_array)
    possible_years = []

    ambiguous_date_string_array.flat_map do |ds|
      possible_years << ds.scan(/\d{4}/)
    end

    possible_years.flatten.map(&:to_i).min
  end
end