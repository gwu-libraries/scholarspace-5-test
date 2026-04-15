# frozen_string_literal: true

module Hyrax
  module Riiif
    class EncodedIdFileResolver < FileResolver
      private

      def load_file(id)
        normalized_id = id.to_s.gsub('%2F', '/').gsub('%2f', '/')

        fs_id = normalized_id.sub(/\A([^\/]*)\/.*/, '\\1')
        file_set = Hyrax.query_service.find_by(id: fs_id)
        file_metadata = Hyrax.custom_queries.find_original_file(file_set: file_set)
        file_metadata.file.disk_path.to_s
      end
    end
  end
end
