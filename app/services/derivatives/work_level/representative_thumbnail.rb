# frozen_string_literal: true

module Derivatives
  module WorkLevel
    # Work-level representative thumbnail pipeline facade.
    class RepresentativeThumbnail
      def initialize(work)
        @work = work
      end

      def generate_payload
        return nil unless supported_source_file_set_ids.any?

        {
          source_file_set_id: preferred_source_file_set_id
        }
      end

      def persist!(source_file_set_id:)
        return if source_file_set_id.blank?

        Derivatives::WorkLevel::ThumbnailGeneration::Thumbnail.new(@work).ensure_representative_thumbnail!
      end

      private

      def preferred_source_file_set_id
        supported_source_file_set_ids.first
      end

      def supported_source_file_set_ids
        Array(@work.original_member_file_sets)
          .select { |file_set| Derivatives::FileSetLevel::ThumbnailGeneration::Thumbnail.thumbnail_supported_file_set?(file_set) }
          .map { |file_set| file_set.id.to_s }
      end
    end
  end
end
