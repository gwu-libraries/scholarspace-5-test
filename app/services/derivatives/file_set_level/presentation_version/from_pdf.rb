# frozen_string_literal: true

require 'open3'

module Derivatives
  module FileSetLevel
    module PresentationVersion
      class FromPdf
        include ::Constants::DerivativeTypeConstants
        include ::Constants::FileExtensionConstants
        include ::Constants::MimeTypeConstants
        include Concerns::FileSetAttachable
        include Derivatives::Concerns::SourceFileSetMimeDetection
        include FileOperations
        include PersistenceAdapter

        def initialize(work)
          @work = work
        end

        def source_file_set_ids
          source_file_sets.map { |file_set| file_set.id.to_s }
        end

        def generate_to_cache(source_file_set_id:)
          source_file_set = source_file_set_for(source_file_set_id)
          return unless source_file_set
          return unless depositor

          Dir.mktmpdir("presentation_pdf_#{@work.id}_") do |dir|
            source_path = copy_source_to_path(source_file_set, dir: dir)
            filename = presentation_filename(source_file_set, extension: '.pdf')
            output_path = File.join(dir, filename)

            build_presentation(source_path: source_path, output_path: output_path)
            return nil unless File.exist?(output_path)

            cache_payload(source_file_set: source_file_set, output_path: output_path, filename: filename)
          end
        end

        def persist_from_cache(source_file_set_id:, cache_file_identifier:, cache_filename:)
          source_file_set = source_file_set_for(source_file_set_id)
          return unless source_file_set
          return unless depositor

          Dir.mktmpdir("presentation_persist_#{@work.id}_") do |dir|
            cached_io = DerivativeCacheService.instance.fetch_stream(
              file_identifier: cache_file_identifier,
              original_filename: cache_filename
            )
            return unless cached_io

            output_path = File.join(dir, cache_filename)
            File.open(output_path, 'wb') { |io| IO.copy_stream(cached_io, io) }

            existing_text_pdf = existing_text_presentation_pdf_for(source_file_set)
            if existing_text_pdf
              reindex_work_and_file_set(existing_text_pdf)
              return existing_text_pdf
            end

            existing = linked_presentation_file_set(source_file_set: source_file_set, filename: cache_filename)
            persisted_file_set = if existing
              replace_file_set_file(file_set: existing, file_path: output_path, user: depositor)
            else
              attach_single_file_to_work(
                file_path: output_path,
                user: depositor,
                service_file: true,
                source_file_set: source_file_set,
                derivative_type_override: DERIVATIVE_TYPE_PRESENTATION_VERSION
              )
            end

            reindex_work_and_file_set(persisted_file_set) if persisted_file_set
          ensure
            cached_io&.close
          end
        end

        private

        def source_file_sets
          @work.member_file_sets.select do |file_set|
            !file_set.service_file && source_pdf_file_set?(file_set)
          end
        end

        def source_file_set_for(source_file_set_id)
          source_file_sets.find { |file_set| file_set.id.to_s == source_file_set_id.to_s }
        end

        def copy_source_to_path(source_file_set, dir:)
          original_filename = source_file_set.original_file&.original_filename.to_s
          extension = File.extname(original_filename)
          extension = '.bin' if extension.blank?
          source_path = File.join(dir, "#{source_file_set.id}#{extension}")
          copy_file_to_disk(source_file_set.original_file.file_identifier, source_path)
          source_path
        end

        def presentation_filename(source_file_set, extension:)
          original_filename = source_file_set.original_file&.original_filename.to_s
          base_name = File.basename(original_filename, File.extname(original_filename))
          "#{base_name}#{PRESENTATION_VERSION_FILENAME_STEM}#{extension}"
        end

        def build_presentation(source_path:, output_path:)
          cmd = [
            'gs',
            '-dBATCH',
            '-dNOPAUSE',
            '-sDEVICE=pdfwrite',
            '-dCompatibilityLevel=1.4',
            '-dPDFSETTINGS=/ebook',
            "-sOutputFile=#{output_path}",
            source_path
          ]

          _stdout, stderr, status = Open3.capture3(*cmd)
          return if status.success?

          raise "Unable to create PDF presentation version: #{stderr.to_s.strip.truncate(300)}"
        end

        def reindex_work_and_file_set(file_set)
          @work = save_and_index(@work)
          index_resources([file_set])
        end

        def linked_presentation_file_set(source_file_set:, filename:)
          @work.member_file_sets.find do |file_set|
            next false unless file_set.service_file

            attached_name = file_set.original_file&.original_filename.to_s
            next false unless attached_name == filename
            next false unless DerivativeLinkResolver.source_file_set_id_for(file_set) == source_file_set.id.to_s

            related_values = DerivativeLinkResolver.related_url_values_for(file_set)
            related_values.include?("#{THUMBNAIL_DERIVATIVE_PREFIX}#{DERIVATIVE_TYPE_PRESENTATION_VERSION}")
          end
        rescue StandardError
          false
        end

        def existing_text_presentation_pdf_for(source_file_set)
          linked_presentation_file_sets(source_file_set).find do |file_set|
            presentation_pdf_contains_embedded_text?(file_set)
          end
        end

        def linked_presentation_file_sets(source_file_set)
          @work.member_file_sets.select do |file_set|
            next false unless file_set.service_file
            next false unless DerivativeLinkResolver.source_file_set_id_for(file_set) == source_file_set.id.to_s
            next false unless file_set.original_file&.original_filename.to_s.downcase.end_with?('.pdf')

            related_values = DerivativeLinkResolver.related_url_values_for(file_set)
            related_values.include?("#{THUMBNAIL_DERIVATIVE_PREFIX}#{DERIVATIVE_TYPE_PRESENTATION_VERSION}")
          end
        rescue StandardError
          []
        end

        def presentation_pdf_contains_embedded_text?(file_set)
          file_identifier = file_set.original_file&.file_identifier
          return false if file_identifier.blank?

          Dir.mktmpdir('presentation_embedded_text_check_') do |temp_dir|
            pdf_path = File.join(temp_dir, 'presentation.pdf')
            copy_file_to_disk(file_identifier, pdf_path)
            pdf_contains_embedded_text?(pdf_path)
          end
        rescue StandardError
          false
        end

        def pdf_contains_embedded_text?(pdf_path)
          stdout, _stderr, status = Open3.capture3(
            'pdftotext',
            '-q',
            '-f', '1',
            '-l', '5',
            pdf_path,
            '-'
          )
          return false unless status.success?

          stdout.to_s.scan(/[[:alpha:]]/).length >= 40
        rescue StandardError
          false
        end

        def cache_payload(source_file_set:, output_path:, filename:)
          cache_file_identifier = cache_file_identifier_for(source_file_set_id: source_file_set.id, filename: filename)
          DerivativeCacheService.instance.store_derivative_from_path(
            file_identifier: cache_file_identifier,
            original_filename: filename,
            source_path: output_path,
            derivative_type: DERIVATIVE_TYPE_PRESENTATION_VERSION
          )

          {
            source_file_set_id: source_file_set.id.to_s,
            cache_file_identifier: cache_file_identifier,
            cache_filename: filename
          }
        end

        def cache_file_identifier_for(source_file_set_id:, filename:)
          "derivatives:presentation_version:work:#{@work.id}:source:#{source_file_set_id}:#{filename}"
        end

        def depositor
          @depositor ||= User.find_by(email: @work.depositor)
        end
      end
    end
  end
end