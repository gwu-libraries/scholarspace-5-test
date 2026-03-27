Rails.application.config.to_prepare do
  module Hyrax
    module FindAccessControlNilGuard
      def find_access_control_for(resource:)
        super
      rescue NoMethodError
        raise(Valkyrie::Persistence::ObjectNotFoundError)
      end
    end
  end

  if defined?(Hyrax::CustomQueries::FindAccessControl) &&
     !Hyrax::CustomQueries::FindAccessControl.ancestors.include?(Hyrax::FindAccessControlNilGuard)
    Hyrax::CustomQueries::FindAccessControl.prepend(Hyrax::FindAccessControlNilGuard)
  end
end