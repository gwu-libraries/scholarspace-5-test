# frozen_string_literal: true

module ScholarspaceDerivativesServices
  module Concerns
    module DerivativeCacheable
      extend ActiveSupport::Concern

      private

      def cache_derivative_file(file_path:, file_set:, derivative_type: 'derivative')
        return unless File.exist?(file_path)

        DerivativeCacheService.instance.store_from_path(
          file_identifier: file_set.original_file.file_identifier,
          original_filename: file_set.original_file.original_filename,
          source_path: file_path
        )
      end
    end
  end
end
