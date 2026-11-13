# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CatalogSearchBuilder do
  let(:config) { CatalogController.blacklight_config }
  let(:scope) { double('catalog scope', blacklight_config: config) }
  let(:builder) { described_class.new(scope) }

  it 'uses the Hyrax catalog search with access controls and range support' do
    expect(described_class).to be < Hyrax::CatalogSearchBuilder
    expect(described_class.default_processor_chain).to include(
      :add_access_controls_to_solr_params,
      :show_only_active_records,
      :add_range_limit_params
    )
  end

  it 'does not add range processing to other Hyrax searches' do
    expect(Hyrax::CatalogSearchBuilder.default_processor_chain).not_to include(:add_range_limit_params)
  end

  it 'is configured for the catalog Date Created facet' do
    expect(config.search_builder_class).to eq(described_class)
    expect(config.facet_fields['year_created_isim'].label).to eq('Date Created')
    expect(config.facet_fields['year_created_isim'].range).to be_truthy
  end

  it 'requests creation-year statistics needed to render the range filter' do
    params = {}
    builder.add_range_limit_params(params)

    expect(params['stats']).to eq('true')
    expect(params['stats.field']).to include('year_created_isim')
  end

  it 'filters results and requests distribution buckets for a selected range' do
    builder.with(range: { 'year_created_isim' => { begin: '1900', end: '1940' } })
    params = Blacklight::Solr::Request.new
    builder.add_facet_fq_to_solr(params)
    builder.add_range_limit_params(params)

    expect(params[:fq]).to include('year_created_isim:[1900 TO 1940]')
    expect(params[:'facet.query']).to include('year_created_isim:[1920 TO 1921]')
  end

  it 'supports an exact year when all results have the same creation year' do
    builder.with(range: { 'year_created_isim' => { begin: '1920', end: '1920' } })
    params = {}
    builder.add_range_limit_params(params)

    expect(params[:'facet.query']).to eq(['year_created_isim:[1920 TO 1920]'])
  end
end
