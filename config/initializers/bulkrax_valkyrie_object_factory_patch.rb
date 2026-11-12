require 'pry'

Rails.application.config.to_prepare do
  module Hyrax
    module CustomQueries
      ##
      # Finds resources for arbitrary properties using the Solr index.
      # @see https://github.com/samvera/valkyrie/wiki/Queries#custom-queries
      module FindByPropertyValueDecorator
        def find_ids_by_property_pairs(pairs:, field_suffix: :ssim, **options)
                options = { rows: @query_rows }.merge(options)
                query = pairs.map do |k, v|
                  suffix = if field_suffix.is_a? Hash
                             field_suffix[k] || :ssim
                           else
                             field_suffix
                           end
                  "+#{k}_#{suffix}:\"#{RSolr.solr_escape(v)}\""
                end
                binding.pry
                response = Hyrax::SolrService.query_result(query.join(' '), fl: 'id', **options)
                response['response']['docs'].map { |doc| doc['id'] }
          end
      end
    end
  end
  module Bulkrax
    module ValkyrieObjectFactoryDecorator
      def run!
           run
           # reload the object
           object = find
           return object if object&.persisted?
           #binding.pry
           raise(ObjectFactoryInterface::RecordInvalid, object)
      end
    end
    module ObjectFactoryInterfaceDecorator
      def search_by_identifier
            return false if source_identifier_value.blank?
            #binding.pry
            self.class.search_by_property(
              klass: klass,
              search_field: work_identifier_search_field,
              value: source_identifier_value,
              name_field: work_identifier
            )
      end
    end
  end
  #Bulkrax::ValkyrieObjectFactory.prepend Bulkrax::ValkyrieObjectFactoryDecorator
  #Bulkrax::ObjectFactoryInterface.prepend Bulkrax::ObjectFactoryInterfaceDecorator
  #Hyrax::CustomQueries::FindByPropertyValue.prepend Hyrax::CustomQueries::FindByPropertyValueDecorator
end
