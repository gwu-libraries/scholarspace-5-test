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
      include ::DerivativeTypeConstants
      include FileOperations
      include ::FileSetDerivativeMetadata
      include ::MimeTypeConstants
      include PersistenceAdapter
      include StringNormalization

      def initialize(work)
        @work = work
      end

      def call
        pending_source_pdf_file_set_ids.each do |pdf_file_set_id|
          process_file_set(pdf_file_set_id: pdf_file_set_id)
        end
      end

      def pending_source_pdf_file_set_ids
        find_pdf_file_sets_needing_extraction.map { |file_set| file_set.id.to_s }
      end

      def process_file_set(pdf_file_set_id:)
        pdf_file_set = member_file_sets.find { |file_set| file_set.id.to_s == pdf_file_set_id.to_s }
        return unless pdf_file_set
        return unless extraction_target_pdf_file_set?(pdf_file_set)
        return if find_hocr_for_pdf(pdf_file_set)

        process_pdf(pdf_file_set)
      end

      private

      def find_pdf_file_sets_needing_extraction
        member_file_sets.select do |file_set|
          next false unless extraction_target_pdf_file_set?(file_set)

          hocr_file_set = find_hocr_for_pdf(file_set)
          hocr_file_set.nil?
        end
      end

      def find_hocr_for_pdf(pdf_file_set)
        member_file_sets.find do |file_set|
          source_file_set_id_for(file_set) == pdf_file_set.id.to_s && hocr_file_set?(file_set)
        end
      end

      def hocr_file_set?(file_set)
        original_file = file_set.original_file
        return false unless original_file

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

      def process_pdf(pdf_file_set)
        with_temp_directory('pdf_extraction_') do |temp_dir|
          pdf_path = fetch_pdf_file(pdf_file_set, temp_dir)
          return unless pdf_path
          contains_embedded_text = pdf_contains_embedded_text?(pdf_path)
          attach_pdf_derivative_to_work(
            pdf_path: pdf_path,
            temp_dir: temp_dir,
            source_pdf_file_set: pdf_file_set,
            source_has_embedded_text: contains_embedded_text
          )
          return if contains_embedded_text

          hocr_filename = expected_hocr_filename_for(pdf_file_set)
          hocr_path = extract_hocr_for_pdf(pdf_path, temp_dir, hocr_filename)
          return unless hocr_path
          return unless File.exist?(hocr_path)

          attach_hocr_to_work(hocr_path, pdf_file_set)
        end
      end

      def attach_pdf_derivative_to_work(pdf_path:, temp_dir:, source_pdf_file_set:, source_has_embedded_text:)
        return unless source_pdf_file_set
        return if image_joined_pdf_file_set?(source_pdf_file_set)

        derivative_filename = expected_presentation_pdf_filename_for(source_pdf_file_set)
        return if linked_pdf_already_attached?(derivative_filename, source_pdf_file_set)

        output_path = File.join(temp_dir, derivative_filename)

        if source_has_embedded_text
          build_compressed_pdf_derivative(source_pdf_path: pdf_path, output_path: output_path)
        else
          ocr_output_path = File.join(temp_dir, "#{File.basename(derivative_filename, '.pdf')}_ocr_raw.pdf")
          image_paths = convert_pdf_to_images(pdf_path, temp_dir)
          return if image_paths.empty?

          page_pdf_paths = build_ocr_page_pdfs(image_paths: image_paths, temp_dir: temp_dir)
          return if page_pdf_paths.empty?

          concatenate_pdfs(page_pdf_paths, ocr_output_path)
          build_compressed_pdf_derivative(source_pdf_path: ocr_output_path, output_path: output_path)
        end

        return unless File.exist?(output_path)

        user = User.find_by(email: @work.depositor)
        return unless user

        attached = attach_single_file_to_work(
          file_path: output_path,
          user: user,
          service_file: true,
          source_file_set: source_pdf_file_set
        )
        ensure_source_linkage!(file_set: attached, source_file_set: source_pdf_file_set)
        reindex_work_and_file_set(attached) if attached
      end

      def expected_presentation_pdf_filename_for(pdf_file_set)
        original_filename = pdf_file_set.original_file.original_filename.to_s
        base_name = File.basename(original_filename, File.extname(original_filename))
        "#{base_name}#{PRESENTATION_VERSION_FILENAME_STEM}.pdf"
      end

      def build_compressed_pdf_derivative(source_pdf_path:, output_path:)
        cmd = [
          'gs',
          '-dBATCH',
          '-dNOPAUSE',
          '-sDEVICE=pdfwrite',
          '-dCompatibilityLevel=1.4',
          '-dPDFSETTINGS=/ebook',
          "-sOutputFile=#{output_path}",
          source_pdf_path
        ]

        _stdout, stderr, status = Open3.capture3(*cmd)
        return if status.success?

        raise "Unable to build compressed PDF derivative (exit #{status.exitstatus}): #{stderr.to_s.strip.truncate(300)}"
      end

      def linked_pdf_already_attached?(filename, source_pdf_file_set)
        member_file_sets.any? do |file_set|
          next false unless pdf_file_set?(file_set)

          attached_name = file_set.original_file&.original_filename.to_s
          next false unless attached_name == filename

          DerivativeLinkResolver.source_file_set_id_for(file_set) == source_pdf_file_set.id.to_s
        end
      rescue StandardError
        false
      end

      def ensure_source_linkage!(file_set:, source_file_set:)
        return unless file_set && source_file_set

        linked_source_id = DerivativeLinkResolver.source_file_set_id_for(file_set)
        return if linked_source_id == source_file_set.id.to_s

        raise "PDF derivative missing source linkage: file_set=#{file_set.id} source=#{source_file_set.id}"
      end

      def build_ocr_page_pdfs(image_paths:, temp_dir:)
        image_paths.each_with_index.map do |image_path, index|
          page_pdf = File.join(temp_dir, format('ocr_page_%04d.pdf', index + 1))
          output_base = page_pdf.sub(/\.pdf\z/, '')
          cmd = ['tesseract', image_path, output_base, 'pdf']
          _stdout, _stderr, status = Open3.capture3(*cmd)
          generated_pdf = "#{output_base}.pdf"
          next nil unless status.success? && File.exist?(generated_pdf)

          FileUtils.mv(generated_pdf, page_pdf) unless generated_pdf == page_pdf
          page_pdf
        end.compact
      end

      def concatenate_pdfs(page_pdf_paths, output_path)
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
        return if status.success?

        raise "Unable to concatenate OCR page PDFs (exit #{status.exitstatus}): #{stderr.to_s.strip.truncate(300)}"
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

        image_joined_pdf_file_set?(file_set)
      end

      def image_joined_pdf_file_set?(file_set)
        filename = file_set.original_file&.original_filename.to_s
        filename.casecmp(DerivativeFilenameConstants::JOINED_IMAGES_PDF_FILENAME).zero?
      end

      def pdf_file_set?(file_set)
        mime_type = normalize_mime_type(file_set.original_file&.mime_type)
        filename = normalize_filename(file_set.original_file&.original_filename)

        mime_type.start_with?(PDF_MIME_TYPE) || filename.end_with?('.pdf')
      end
    end
  end
  end
end
