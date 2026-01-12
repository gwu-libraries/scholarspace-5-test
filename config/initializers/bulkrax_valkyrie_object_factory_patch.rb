Rails.application.config.to_prepare do
  module Bulkrax
    module ValkyrieObjectFactoryDecorator
      module ClassMethods
        def search_by_property(value:, search_field:, field: nil, name_field: nil, **)
          name_field ||= field
          raise 'Expected named_field or field got nil' if name_field.blank?
          return if value.blank?

          # Return nil or a single object.
          # patching query service to use the correct arguments per the query as implemented here: https://github.com/samvera/hyrax/pull/7320 ----> @dolsysmith
          Hyrax.query_service.custom_queries.find_by_property_value(property: name_field, value: value,
                                                                    field_type: :stored_searchable)
        end
      end

      def self.prepended(mod)
        mod.singleton_class.prepend(ClassMethods)
      end
    end
  end
  Bulkrax::ValkyrieObjectFactory.prepend Bulkrax::ValkyrieObjectFactoryDecorator
end
