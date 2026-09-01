# frozen_string_literal: true

require 'open3'
require 'fileutils'
require 'thread'

module Derivatives
  module FileSetLevel
    module TextExtraction
      # Entry point for extracting searchable text from source PDFs.
      class FromPdf
        EMBEDDED_TEXT_SAMPLE_PAGES = 5
        EMBEDDED_TEXT_MIN_WORDS = 8
        EMBEDDED_TEXT_MIN_ALPHA_CHARS = 40
        EMBEDDED_TEXT_MIN_ALPHA_RATIO = 0.2

        include Concerns::FileSetAttachable
        include Concerns::TextExtraction::HocrGeneratable
        include Concerns::TextExtraction::HocrMergeable
        include Concerns::DerivativeCacheWriter
        include ::Constants::DerivativeTypeConstants
        include FileOperations
        include ::FileSetDerivativeMetadata
        include ::Constants::MimeTypeConstants
        include PersistenceAdapter
        include StringNormalization

        def initialize(work)
          @work = work
        end

        def call
          pending_source_pdf_file_set_ids.each do |pdf_file_set_id|
            payload = generate_to_cache(pdf_file_set_id: pdf_file_set_id)
            next unless payload

            persist_from_cache(
              source_file_set_id: payload.fetch(:source_file_set_id),
              cache_file_identifier_hocr: payload.fetch(:cache_file_identifier_hocr),
              cache_filename_hocr: payload.fetch(:cache_filename_hocr),
              cache_file_identifier_pdf: payload.fetch(:cache_file_identifier_pdf),
              cache_filename_pdf: payload.fetch(:cache_filename_pdf)
            )
          end
        end

        def pending_source_pdf_file_set_ids
          find_pdf_file_sets_needing_extraction.map { |file_set| file_set.id.to_s }
        end

        def generate_to_cache(pdf_file_set_id:)
          pdf_file_set = member_file_sets.find { |file_set| file_set.id.to_s == pdf_file_set_id.to_s }
          return unless pdf_file_set
          return unless extraction_target_pdf_file_set?(pdf_file_set)
          return if extraction_artifacts_complete_for?(pdf_file_set)

          generate_and_cache_pdf_derivatives(pdf_file_set)
        end

        def persist_from_cache(source_file_set_id:, cache_file_identifier_hocr:, cache_filename_hocr:,
                                        cache_file_identifier_pdf:, cache_filename_pdf:)
          source_pdf_file_set = member_file_sets.find { |file_set| file_set.id.to_s == source_file_set_id.to_s }
          return unless source_pdf_file_set
          return unless extraction_target_pdf_file_set?(source_pdf_file_set)

          Dir.mktmpdir("pdf_text_persist_#{@work.id}_") do |dir|
            # Persist hOCR
            if cache_file_identifier_hocr.present? && cache_filename_hocr.present?
              hocr_path = fetch_from_cache_to_disk(
                cache_file_identifier: cache_file_identifier_hocr,
                cache_filename: cache_filename_hocr,
                dir: dir
              )
              attach_hocr_to_work(hocr_path, source_pdf_file_set) if hocr_path
            end

            # Persist embedded-text PDF (presentation version)
            pdf_path = fetch_from_cache_to_disk(
              cache_file_identifier: cache_file_identifier_pdf,
              cache_filename: cache_filename_pdf,
              dir: dir,
              skip_if_attached: false
            )
            attach_presentation_pdf_to_work(pdf_path, source_pdf_file_set) if pdf_path
          end
        end

        private

        def find_pdf_file_sets_needing_extraction
          member_file_sets.select do |file_set|
            next false unless extraction_target_pdf_file_set?(file_set)

            !extraction_artifacts_complete_for?(file_set)
          end
        end

        def extraction_artifacts_complete_for?(pdf_file_set)
          hocr_file_set = find_hocr_for_pdf(pdf_file_set)
          return false unless hocr_file_set || source_pdf_contains_embedded_text?(pdf_file_set)

          presentation_file_set = find_presentation_pdf_for(pdf_file_set)
          return false unless presentation_file_set

          presentation_pdf_contains_embedded_text?(presentation_file_set)
        end

        def source_pdf_contains_embedded_text?(pdf_file_set)
          file_identifier = pdf_file_set.original_file&.file_identifier
          return false if file_identifier.blank?

          with_temp_directory('source_embedded_text_check_') do |temp_dir|
            pdf_path = File.join(temp_dir, 'source.pdf')
            copy_file_to_disk(file_identifier, pdf_path)
            return pdf_contains_embedded_text?(pdf_path)
          end
        rescue StandardError
          false
        end

        def find_hocr_for_pdf(pdf_file_set)
          member_file_sets.find do |file_set|
            source_file_set_id_for(file_set) == pdf_file_set.id.to_s && hocr_file_set?(file_set)
          end
        end

        def find_presentation_pdf_for(pdf_file_set)
          source_id = pdf_file_set.id.to_s

          candidates = member_file_sets.select do |file_set|
            next false unless file_set.service_file
            next false unless source_file_set_id_for(file_set) == source_id

            related_values = DerivativeLinkResolver.related_url_values_for(file_set)
            related_values.include?("#{THUMBNAIL_DERIVATIVE_PREFIX}#{DERIVATIVE_TYPE_PRESENTATION_VERSION}")
          end

          candidates.find { |file_set| presentation_pdf_contains_embedded_text?(file_set) } || candidates.first
        rescue StandardError
          nil
        end

        def presentation_pdf_contains_embedded_text?(presentation_file_set)
          file_identifier = presentation_file_set.original_file&.file_identifier
          return false if file_identifier.blank?

          with_temp_directory('presentation_embedded_text_check_') do |temp_dir|
            pdf_path = File.join(temp_dir, 'presentation.pdf')
            copy_file_to_disk(file_identifier, pdf_path)
            return pdf_contains_embedded_text?(pdf_path)
          end
        rescue StandardError
          false
        end

        def hocr_file_set?(file_set)
          original_file = file_set.original_file
          return false unless original_file

          related_values = DerivativeLinkResolver.related_url_values_for(file_set)
          return true if related_values.include?("#{THUMBNAIL_DERIVATIVE_PREFIX}#{DERIVATIVE_TYPE_HOCR}")

          filename = original_file.respond_to?(:original_filename) ? original_file.original_filename.to_s : ''
          return true if filename.downcase.end_with?('.hocr')

          mime_type = normalize_mime_type(original_file.respond_to?(:mime_type) ? original_file.mime_type : '')
          mime_type == HOCR_MIME_TYPE
        end

        def source_file_set_id_for(file_set)
          DerivativeLinkResolver.source_file_set_id_for(file_set)
        end

        def expected_hocr_filename_for(pdf_file_set)
          original_filename = pdf_file_set.original_file.original_filename.to_s
          base_name = File.basename(original_filename, File.extname(original_filename))
          "#{base_name}_HOCR.hocr"
        end

        def generate_and_cache_pdf_derivatives(pdf_file_set)
          with_temp_directory('pdf_extraction_') do |temp_dir|
            pdf_path = fetch_pdf_file(pdf_file_set, temp_dir)
            return unless pdf_path

            contains_embedded_text = pdf_contains_embedded_text?(pdf_path)
            pdf_filename = presentation_version_pdf_filename_for(pdf_file_set)
            embedded_pdf_path = if contains_embedded_text
                                  generate_text_preserving_presentation_pdf(pdf_path, temp_dir, pdf_filename)
                                else
                                  generate_embedded_text_pdf(pdf_path, temp_dir, pdf_filename)
                                end
            return unless embedded_pdf_path
            return unless File.exist?(embedded_pdf_path)

            hocr_payload = unless contains_embedded_text
                             hocr_filename = expected_hocr_filename_for(pdf_file_set)
                             hocr_path = extract_hocr_for_pdf(pdf_path, temp_dir, hocr_filename)
                             return unless hocr_path
                             return unless File.exist?(hocr_path)

                             cache_hocr_derivative(pdf_file_set: pdf_file_set, hocr_path: hocr_path)
                           end
            pdf_payload = cache_pdf_derivative(pdf_file_set: pdf_file_set, embedded_pdf_path: embedded_pdf_path)

            {
              source_file_set_id: pdf_file_set.id.to_s,
              cache_file_identifier_hocr: hocr_payload&.fetch(:cache_file_identifier),
              cache_filename_hocr: hocr_payload&.fetch(:cache_filename),
              cache_file_identifier_pdf: pdf_payload.fetch(:cache_file_identifier),
              cache_filename_pdf: pdf_payload.fetch(:cache_filename)
            }
          end
        end

        def cache_hocr_derivative(pdf_file_set:, hocr_path:)
          cache_filename = File.basename(hocr_path)
          cache_file_identifier = cache_file_identifier_for(
            source_file_set_id: pdf_file_set.id,
            filename: cache_filename
          )
          DerivativeCacheService.instance.store_derivative_from_path(
            file_identifier: cache_file_identifier,
            original_filename: cache_filename,
            source_path: hocr_path,
            derivative_type: DERIVATIVE_TYPE_HOCR
          )

          { cache_file_identifier: cache_file_identifier, cache_filename: cache_filename }
        end

        def cache_pdf_derivative(pdf_file_set:, embedded_pdf_path:)
          cache_filename = File.basename(embedded_pdf_path)
          cache_file_identifier = cache_file_identifier_for(
            source_file_set_id: pdf_file_set.id,
            filename: cache_filename
          )
          DerivativeCacheService.instance.store_derivative_from_path(
            file_identifier: cache_file_identifier,
            original_filename: cache_filename,
            source_path: embedded_pdf_path,
            derivative_type: DERIVATIVE_TYPE_PDF_DERIVATIVE
          )

          { cache_file_identifier: cache_file_identifier, cache_filename: cache_filename }
        end

        def with_temp_directory(prefix)
          temp_dir = Dir.mktmpdir(prefix)
          yield temp_dir
        ensure
          FileUtils.rm_rf(temp_dir) if temp_dir && File.exist?(temp_dir)
        end

        def fetch_pdf_file(file_set, temp_dir)
          pdf_path = File.join(temp_dir, 'document.pdf')
          copy_file_to_disk(file_set.original_file.file_identifier, pdf_path)

          cache_derivative(
            file_path: pdf_path,
            file_set: file_set,
            derivative_type: DERIVATIVE_TYPE_PDF
          )

          pdf_path
        rescue StandardError
          nil
        end

        def pdf_contains_embedded_text?(pdf_path)
          cmd = [
            'pdftotext',
            '-q',
            '-f', '1',
            '-l', EMBEDDED_TEXT_SAMPLE_PAGES.to_s,
            pdf_path,
            '-'
          ]

          stdout, _stderr, status = Open3.capture3(*cmd)
          return false unless status.success?

          significant_embedded_text?(stdout)
        rescue StandardError
          false
        end

        def significant_embedded_text?(raw_text)
          normalized_text = normalize_embedded_text(raw_text)
          return false if normalized_text.blank?

          word_count = normalized_text.split.length
          return false if word_count < EMBEDDED_TEXT_MIN_WORDS

          alpha_chars = normalized_text.scan(/[[:alpha:]]/).length
          return false if alpha_chars < EMBEDDED_TEXT_MIN_ALPHA_CHARS

          alpha_ratio = alpha_chars.to_f / normalized_text.length
          alpha_ratio >= EMBEDDED_TEXT_MIN_ALPHA_RATIO
        end

        def normalize_embedded_text(text)
          sanitized = text.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: ' ')
          sanitized
            .gsub(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/, ' ')
            .unicode_normalize(:nfkc)
            .gsub(/\s+/, ' ')
            .strip
        end

        def extract_hocr_for_pdf(pdf_path, temp_dir, hocr_filename)
          image_paths = convert_pdf_to_images(pdf_path, temp_dir)
          return nil if image_paths.empty?

          hocr_pages_dir = hocr_pages_dir_for(temp_dir)
          ensure_directory_exists(hocr_pages_dir)

          hocr_paths = generate_hocr_files_in_parallel(image_paths: image_paths, hocr_pages_dir: hocr_pages_dir)
          return nil if hocr_paths.empty?

          merge_hocr_paths(hocr_paths: hocr_paths, temp_dir: temp_dir, hocr_filename: hocr_filename)
        rescue StandardError
          nil
        end

        def hocr_pages_dir_for(temp_dir)
          File.join(temp_dir, 'hocr_pages')
        end

        def merge_hocr_paths(hocr_paths:, temp_dir:, hocr_filename:)
          @working_dir = temp_dir
          @joined_hocr_filename = hocr_filename
          merged_path = merge_hocr_files(hocr_paths)
          return nil unless merged_path && File.exist?(merged_path)

          merged_path
        end

        def convert_pdf_to_images(pdf_path, temp_dir)
          output_prefix = File.join(temp_dir, 'page')
          cmd = ['pdftoppm', '-r', '150', '-png', pdf_path, output_prefix]
          _stdout, _stderr, status = Open3.capture3(*cmd)
          return [] unless status.success?

          image_paths = Dir.glob(File.join(temp_dir, 'page-*.png')).sort
          image_paths.any? ? image_paths : []
        rescue StandardError
          []
        end

        def generate_hocr_files_in_parallel(image_paths:, hocr_pages_dir:)
          ocr_workers = [2, image_paths.length].min
          queue = Queue.new
          enqueue_ocr_jobs(queue: queue, image_paths: image_paths)
          hocr_paths = Array.new(image_paths.length)
          errors = Queue.new

          threads = run_ocr_workers(
            worker_count: ocr_workers,
            queue: queue,
            errors: errors,
            hocr_paths: hocr_paths,
            hocr_pages_dir: hocr_pages_dir
          )

          threads.each(&:join)
          raise errors.pop unless errors.empty?

          hocr_paths.compact
        end

        def enqueue_ocr_jobs(queue:, image_paths:)
          image_paths.each_with_index { |image_path, index| queue << [index, image_path] }
        end

        def run_ocr_workers(worker_count:, queue:, errors:, hocr_paths:, hocr_pages_dir:)
          Array.new(worker_count) do
            Thread.new do
              process_ocr_queue(queue: queue, errors: errors, hocr_paths: hocr_paths, hocr_pages_dir: hocr_pages_dir)
            end
          end
        end

        def process_ocr_queue(queue:, errors:, hocr_paths:, hocr_pages_dir:)
          loop do
            break if errors.size.positive?

            begin
              index, image_path = queue.pop(true)
            rescue ThreadError
              break
            end

            page_hocr_path = File.join(hocr_pages_dir, format('page_%04d_HOCR.hocr', index + 1))
            hocr_paths[index] = generate_hocr_file(
              image_path: image_path,
              output_hocr_path: page_hocr_path,
              error_message: "Tesseract OCR failed for work #{@work.id}"
            )
          rescue StandardError => e
            errors << e
            break
          end
        end

        def joined_hocr_filename
          @joined_hocr_filename || 'merged_HOCR.hocr'
        end

        def attach_hocr_to_work(hocr_path, source_pdf_file_set)
          user = User.find_by(email: @work.depositor)
          return unless user

          filename = File.basename(hocr_path)
          if file_set_attached_with_name?(filename)
            existing_file_set = member_file_sets.find do |member_file_set|
              member_file_set.original_file&.original_filename.to_s == filename
            end
            if existing_file_set
              reindex_work_and_file_set(existing_file_set)
              return existing_file_set
            end
            return source_pdf_file_set
          end

          file_set = attach_single_file_to_work(
            file_path: hocr_path,
            user: user,
            service_file: true,
            source_file_set: source_pdf_file_set
          )

          if file_set
            reindex_work_and_file_set(file_set)
            cache_derivative(
              file_path: hocr_path,
              file_set: file_set,
              derivative_type: DERIVATIVE_TYPE_HOCR
            )
          end

          file_set
        end

        def member_file_sets
          @member_file_sets ||= @work.member_ids.map { |id| Hyrax.query_service.find_by(id: id) }
        end

        def reindex_work_and_file_set(file_set)
          @work = save_and_index(@work)
          index_resources([file_set])
        end

        def extraction_target_pdf_file_set?(file_set)
          return false unless pdf_file_set?(file_set)
          return true unless file_set.service_file

          reading_mode_pdf_file_set?(file_set)
        end

        def reading_mode_pdf_file_set?(file_set)
          filename = file_set.original_file&.original_filename.to_s
          filename.casecmp?(Constants::DerivativeFilenameConstants::READING_MODE_PDF_FILENAME)
        end

        def pdf_file_set?(file_set)
          mime_type = normalize_mime_type(file_set.original_file&.mime_type)
          filename = normalize_filename(file_set.original_file&.original_filename)

          mime_type.start_with?(PDF_MIME_TYPE) || filename.end_with?('.pdf')
        end

        def cache_file_identifier_for(source_file_set_id:, filename:)
          "derivatives:text_extraction_from_pdf:work:#{@work.id}:source:#{source_file_set_id}:#{filename}"
        end

        def presentation_version_pdf_filename_for(pdf_file_set)
          original_filename = pdf_file_set.original_file.original_filename.to_s
          base_name = File.basename(original_filename, File.extname(original_filename))
          "#{base_name}#{Constants::DerivativeFilenameConstants::PDF_PRESENTATION_VERSION_SUFFIX}"
        end

        def generate_embedded_text_pdf(pdf_path, temp_dir, pdf_filename)
          output_dir = File.join(temp_dir, 'embedded_pdf_pages')
          ensure_directory_exists(output_dir)
          output_path = File.join(output_dir, pdf_filename)

          # Convert PDF to images, generate searchable PDFs, concatenate
          image_paths = convert_pdf_to_images(pdf_path, temp_dir)
          return nil if image_paths.empty?

          page_pdf_paths = generate_searchable_page_pdfs(image_paths, output_dir)
          return nil if page_pdf_paths.empty?

          concatenate_pdfs_for_presentation(page_pdf_paths, output_path)
          File.exist?(output_path) ? output_path : nil
        rescue StandardError => e
          Rails.logger.error(
            "FromPdf: generate_embedded_text_pdf failed work_id=#{@work.id} " \
            "error=#{e.class} #{e.message}"
          )
          nil
        end

        def generate_text_preserving_presentation_pdf(pdf_path, temp_dir, pdf_filename)
          output_dir = File.join(temp_dir, 'embedded_pdf_pages')
          ensure_directory_exists(output_dir)
          output_path = File.join(output_dir, pdf_filename)
          FileUtils.cp(pdf_path, output_path)

          File.exist?(output_path) ? output_path : nil
        rescue StandardError => e
          Rails.logger.warn(
            "FromPdf: generate_text_preserving_presentation_pdf error work_id=#{@work.id} " \
            "error=#{e.class}: #{e.message}"
          )
          nil
        end

        def generate_searchable_page_pdfs(image_paths, output_dir)
          ocr_workers = [2, image_paths.length].min
          queue = Queue.new
          enqueue_pdf_generation_jobs(queue: queue, image_paths: image_paths)
          page_pdf_paths = Array.new(image_paths.length)
          errors = Queue.new

          threads = run_pdf_generation_workers(
            worker_count: ocr_workers,
            queue: queue,
            errors: errors,
            page_pdf_paths: page_pdf_paths,
            output_dir: output_dir
          )

          threads.each(&:join)
          raise errors.pop unless errors.empty?

          page_pdf_paths.compact.sort
        rescue StandardError => e
          Rails.logger.error(
            "FromPdf: generate_searchable_page_pdfs failed work_id=#{@work.id} " \
            "error=#{e.class} #{e.message}"
          )
          []
        end

        def enqueue_pdf_generation_jobs(queue:, image_paths:)
          image_paths.each_with_index { |image_path, index| queue << [index, image_path] }
        end

        def run_pdf_generation_workers(worker_count:, queue:, errors:, page_pdf_paths:, output_dir:)
          Array.new(worker_count) do
            Thread.new do
              process_pdf_generation_queue(
                queue: queue,
                errors: errors,
                page_pdf_paths: page_pdf_paths,
                output_dir: output_dir
              )
            end
          end
        end

        def process_pdf_generation_queue(queue:, errors:, page_pdf_paths:, output_dir:)
          loop do
            break if errors.size.positive?

            begin
              index, image_path = queue.pop(true)
            rescue ThreadError
              break
            end

            page_pdf_path = File.join(output_dir, format('page_%04d.pdf', index + 1))
            page_pdf_paths[index] = generate_searchable_page_pdf(
              image_path: image_path,
              output_pdf_path: page_pdf_path,
              page_number: index + 1
            )
          rescue StandardError => e
            errors << e
            break
          end
        end

        def generate_searchable_page_pdf(image_path:, output_pdf_path:, page_number:)
          cmd = ['tesseract', image_path, output_pdf_path.sub(/\.pdf\z/, ''), 'pdf']
          _stdout, stderr, status = Open3.capture3(*cmd)
          return output_pdf_path if status.success? && File.exist?(output_pdf_path)

          Rails.logger.warn(
            "FromPdf: tesseract PDF generation failed for page #{page_number} " \
            "work_id=#{@work.id} stderr=#{stderr.to_s.strip.truncate(200)}"
          )
          nil
        rescue StandardError => e
          Rails.logger.warn(
            "FromPdf: generate_searchable_page_pdf error page=#{page_number} " \
            "work_id=#{@work.id} error=#{e.class}: #{e.message}"
          )
          nil
        end

        def concatenate_pdfs_for_presentation(page_pdf_paths, output_path)
          return if concatenate_pdfs_with_pdfunite(page_pdf_paths, output_path)

          cmd = [
            'gs',
            '-dBATCH',
            '-dNOPAUSE',
            '-sDEVICE=pdfwrite',
            '-dCompatibilityLevel=1.4',
            "-sOutputFile=#{output_path}",
            *page_pdf_paths
          ]
          _stdout, stderr, status = Open3.capture3(*cmd)
          unless status.success?
            Rails.logger.error(
              "FromPdf: gs concatenate failed work_id=#{@work&.id} " \
              "page_count=#{page_pdf_paths.size} " \
              "exit_status=#{status.exitstatus} stderr=#{stderr.strip.truncate(500)}"
            )
            raise "Unable to concatenate page PDFs (exit #{status.exitstatus}): #{stderr.strip.truncate(300)}"
          end
        end

        def concatenate_pdfs_with_pdfunite(page_pdf_paths, output_path)
          _stdout, stderr, status = Open3.capture3('pdfunite', *page_pdf_paths, output_path)
          return true if status.success? && File.exist?(output_path)

          Rails.logger.warn(
            "FromPdf: pdfunite concatenate failed work_id=#{@work&.id} " \
            "page_count=#{page_pdf_paths.size} " \
            "exit_status=#{status.exitstatus} stderr=#{stderr.to_s.strip.truncate(300)}"
          )
          false
        rescue Errno::ENOENT
          false
        end

        def fetch_from_cache_to_disk(cache_file_identifier:, cache_filename:, dir:, skip_if_attached: true)
          return nil if skip_if_attached && file_set_attached_with_name?(cache_filename)

          cached_io = DerivativeCacheService.instance.fetch_stream(
            file_identifier: cache_file_identifier,
            original_filename: cache_filename
          )
          return nil unless cached_io

          file_path = File.join(dir, cache_filename)
          File.open(file_path, 'wb') { |io| IO.copy_stream(cached_io, io) }
          file_path
        ensure
          cached_io&.close
        end

        def attach_presentation_pdf_to_work(pdf_path, source_pdf_file_set)
          user = User.find_by(email: @work.depositor)
          return unless user
          return unless File.exist?(pdf_path)

          filename = File.basename(pdf_path)
          file_set = nil

          with_work_lock do
            @work = reload_work
            @member_file_sets = nil

            existing_file_sets = find_existing_presentation_pdfs_for_source(source_pdf_file_set: source_pdf_file_set)
            existing_text_file_set = existing_file_sets.find { |existing_file_set|
              presentation_pdf_contains_embedded_text?(existing_file_set)
            }

            if existing_text_file_set
              reindex_work_and_file_set(existing_text_file_set)
              return existing_text_file_set
            end

            existing_file_sets.each { |existing_file_set| remove_existing_member_file_set(existing_file_set) }
            @member_file_sets = nil

            file_set = attach_single_file_to_work(
              file_path: pdf_path,
              user: user,
              service_file: true,
              source_file_set: source_pdf_file_set,
              derivative_type_override: DERIVATIVE_TYPE_PRESENTATION_VERSION
            )
          end

          if file_set
            reindex_work_and_file_set(file_set)
            cache_derivative(
              file_path: pdf_path,
              file_set: file_set,
              derivative_type: DERIVATIVE_TYPE_PRESENTATION_VERSION
            )
          end

          file_set
        end

        def find_existing_presentation_pdfs_for_source(source_pdf_file_set:)
          source_id = source_pdf_file_set.id.to_s
          member_file_sets.select do |member_file_set|
            next false unless member_file_set.service_file
            next false unless member_file_set.original_file&.original_filename.to_s.downcase.end_with?('.pdf')
            next false unless source_file_set_id_for(member_file_set) == source_id

            related_values = DerivativeLinkResolver.related_url_values_for(member_file_set)
            related_values.include?("#{THUMBNAIL_DERIVATIVE_PREFIX}#{DERIVATIVE_TYPE_PRESENTATION_VERSION}")
          end
        rescue StandardError
          []
        end

        def remove_existing_member_file_set(file_set)
          removed_id = file_set.id.to_s
          @work = reload_work
          @work.member_ids = Array(@work.member_ids).reject { |member_id| member_id.to_s == removed_id }
          @work = save_and_index(@work)

          Hyrax.persister.delete(resource: file_set)
          Hyrax.index_adapter.delete(resource: file_set)
        rescue StandardError => e
          Rails.logger.warn(
            "FromPdf: failed to remove existing presentation file_set work_id=#{@work.id} " \
            "file_set_id=#{file_set&.id} error=#{e.class}: #{e.message}"
          )
        end
      end
    end
  end
end
