# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CatalogController, type: :controller do
  describe 'creation-year validation' do
    let(:field) { 'year_created_isim' }

    it 'redirects reversed ranges with an alert, preserving other search filters' do
      get :index, params: {
        q: 'history', search_field: 'all_fields', page: '2', locale: 'en',
        f: { 'creator_sim' => ['alex'] },
        range: { field => { begin: '1920', end: '1919' } }
      }

      expect(response).to redirect_to(search_catalog_path(
        q: 'history', search_field: 'all_fields', locale: 'en', f: { 'creator_sim' => ['alex'] }
      ))
      expect(flash[:alert]).to eq(I18n.t('catalog.range_validation.reversed'))
    end

    [
      { begin: 'not-a-year', end: '1920' },
      { begin: '1919.5', end: '1920' },
      { begin: '1920', end: '2147483648' },
      { begin: '-2147483649', end: '1920' },
      { begin: ['1920'], end: '1921' },
      '1920'
    ].each do |bounds|
      it "rejects invalid year bounds #{bounds.inspect}" do
        get :index, params: { range: { field => bounds } }

        expect(response).to redirect_to(search_catalog_path)
        expect(flash[:alert]).to eq(I18n.t('catalog.range_validation.invalid_year'))
      end
    end

    it 'rejects a malformed range parameter' do
      get :index, params: { range: '1920' }

      expect(response).to redirect_to(search_catalog_path)
      expect(flash[:alert]).to eq(I18n.t('catalog.range_validation.invalid_year'))
    end

    it 'allows the plugin filter for records without a creation year' do
      controller.params = ActionController::Parameters.new(
        range: { "-#{field}" => [Blacklight::Engine.config.blacklight.facet_missing_param] }
      )

      expect(controller).not_to receive(:redirect_to)
      controller.send(:validate_catalog_ranges)
    end

    [
      { begin: '1920', end: '1920' },
      { begin: '1919', end: '1920' },
      { begin: '', end: '1920' },
      { begin: '1920', end: '' },
      { begin: '', end: '' }
    ].each do |bounds|
      it "allows valid or open-ended bounds #{bounds.inspect}" do
        controller.params = ActionController::Parameters.new(range: { field => bounds })

        expect(controller).not_to receive(:redirect_to)
        controller.send(:validate_catalog_ranges)
        expect(flash[:alert]).to be_nil
      end
    end

    it 'returns a validation message instead of an exception for reversed distribution bounds' do
      get :range_limit, params: { range_field: field, range_start: '1920', range_end: '1919' }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to eq(I18n.t('catalog.range_validation.reversed'))
    end

    it 'rejects non-integer distribution bounds' do
      get :range_limit, params: { range_field: field, range_start: 'abc', range_end: '1920' }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to eq(I18n.t('catalog.range_validation.invalid_year'))
    end
  end
end
