# frozen_string_literal: true

module Derivatives
  module Concerns
    module SourceFileSetMimeDetection
      include ::Constants::FileExtensionConstants
      include ::Constants::MimeTypeConstants
      include ::StringNormalization

      GENERIC_OCTET_STREAM_MIME_TYPE = 'application/octet-stream'.freeze
      AUDIO_FILE_EXTENSIONS = %w[mp3 wav m4a aac flac ogg oga opus].freeze
      VIDEO_FILE_EXTENSIONS = %w[mp4 m4v mov webm mkv avi mpeg mpg].freeze

      private

      def effective_mime_type_for_file_set(file_set)
        mime = normalize_mime_type(file_set.original_file&.mime_type.to_s)
        return mime if specific_source_mime_type?(mime)

        inferred = inferred_mime_type_from_filename(file_set.original_file&.original_filename.to_s)
        return inferred if specific_source_mime_type?(inferred)

        mime.presence || inferred
      end

      def source_image_file_set?(file_set)
        effective_mime_type_for_file_set(file_set).start_with?(IMAGE_MIME_PREFIX)
      end

      def source_audio_visual_file_set?(file_set)
        effective_mime_type_for_file_set(file_set).start_with?(*AUDIO_VISUAL_MIME_PREFIXES)
      end

      def source_pdf_file_set?(file_set)
        effective_mime_type_for_file_set(file_set) == PDF_MIME_TYPE
      end

      def source_video_file_set?(file_set)
        effective_mime_type_for_file_set(file_set).start_with?(VIDEO_MIME_PREFIX)
      end

      def specific_source_mime_type?(mime)
        mime.present? && mime != GENERIC_OCTET_STREAM_MIME_TYPE
      end

      def inferred_mime_type_from_filename(filename)
        return PDF_MIME_TYPE if matches_extension?(filename, 'pdf')
        return "#{AUDIO_MIME_PREFIX}unknown" if matches_extension?(filename, *AUDIO_FILE_EXTENSIONS)
        return "#{VIDEO_MIME_PREFIX}unknown" if matches_extension?(filename, *VIDEO_FILE_EXTENSIONS)
        return "#{IMAGE_MIME_PREFIX}unknown" if matches_extension?(filename, *IMAGE_EXTENSIONS)

        ''
      end
    end
  end
end
