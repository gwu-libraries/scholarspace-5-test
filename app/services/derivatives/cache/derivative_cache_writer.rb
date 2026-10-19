# frozen_string_literal: true

module Derivatives
  module Cache
    module DerivativeCacheWriter
      extend ActiveSupport::Concern
      include ::Derivatives::Constants::DerivativeTypeConstants

      private

      def cache_derivative(file_path:, file_set:, derivative_type: DERIVATIVE_TYPE_DEFAULT)
        original_file = file_set&.original_file
        return unless original_file

        Derivatives::Cache::Service.instance.store_derivative_from_path(
          file_identifier: original_file.file_identifier,
          original_filename: original_file.original_filename,
          source_path: file_path,
          derivative_type: derivative_type
        )
      end
    end
  end
end
