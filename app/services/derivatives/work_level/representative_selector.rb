# frozen_string_literal: true

module Derivatives
  module WorkLevel
    class RepresentativeSelector
    include ::MimeTypeConstants
    include PersistenceAdapter

    def initialize(work:)
      @work = work
    end

    def call
      return @work unless @work.respond_to?(:representative_id=)

      preferred_source = preferred_representative_source_file_set
      return @work unless preferred_source

      preferred_id = preferred_source.id.to_s
      return @work if @work.representative_id.to_s == preferred_id

      @work.representative_id = preferred_source.id
      @work = save_and_index(@work)
    end

    private

    def preferred_representative_source_file_set
      Array(@work.original_member_file_sets)
        .select { |file_set| representative_priority_for(file_set) < 99 }
        .min_by { |file_set| [representative_priority_for(file_set), representative_sort_name_for(file_set)] }
    end

    def representative_priority_for(file_set)
      mime_type = file_set.original_file&.mime_type.to_s.downcase

      return 0 if av_source_file_set?(file_set, mime_type)
      return 1 if pdf_source_file_set?(file_set, mime_type)
      return 2 if image_source_file_set?(file_set, mime_type)

      99
    end

    def representative_sort_name_for(file_set)
      file_set.original_file&.original_filename.to_s.downcase
    end

    def av_source_file_set?(file_set, mime_type)
      (file_set.respond_to?(:audio?) && file_set.audio?) ||
        (file_set.respond_to?(:video?) && file_set.video?) ||
        mime_type.start_with?(*AUDIO_VIDEO_MIME_PREFIXES)
    end

    def pdf_source_file_set?(file_set, mime_type)
      (file_set.respond_to?(:pdf?) && file_set.pdf?) || mime_type == PDF_MIME_TYPE
    end

    def image_source_file_set?(file_set, mime_type)
      (file_set.respond_to?(:image?) && file_set.image?) || mime_type.start_with?(IMAGE_MIME_PREFIX)
    end
  end
  end
end
