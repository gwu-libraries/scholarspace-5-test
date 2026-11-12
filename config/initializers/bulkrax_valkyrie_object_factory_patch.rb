require 'pry'

Rails.application.config.to_prepare do
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
  end
  Bulkrax::ValkyrieObjectFactory.prepend Bulkrax::ValkyrieObjectFactoryDecorator
end
