# frozen_string_literal: true

require 'open3'
require 'fileutils'
require 'thread'

module Derivatives
  class PdfTextExtraction
    include Concerns::FileSetAttachable
    include Concerns::HocrGeneratable
    include Concerns::HocrMergeable
    include Concerns::DerivativeCacheWriter
    include FileOperations
    include FileSetDerivativeMetadata
    include PersistenceAdapter
    include StringNormalization

    def initialize(work)
      @work = work
    end

    def call
      pdf_file_set_ids_needing_extraction.each do |pdf_file_set_id|
        process_file_set(pdf_file_set_id: pdf_file_set_id)
      end
    end

    def pdf_file_set_ids_needing_extraction
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

        # Check if HOCR already exists for this PDF
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
      filename = normalize_filename(original_file.respond_to?(:original_filename) ? original_file.original_filename : '')

      mime_type == 'text/vnd.hocr+html' || filename.end_with?('.hocr')
    end

    def source_file_set_id_for(file_set)
      return '' unless file_set.respond_to?(:related_url)

      extract_source_file_set_id(file_set.related_url)
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

        hocr_filename = expected_hocr_filename_for(pdf_file_set)
        hocr_path = extract_hocr_for_pdf(pdf_path, temp_dir, hocr_filename)
        return unless hocr_path

        return unless File.exist?(hocr_path)

        attach_hocr_to_work(hocr_path, pdf_file_set)
      end
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
        derivative_type: 'pdf'
      )

      pdf_path
    rescue StandardError
      nil
    end

    def extract_hocr_for_pdf(pdf_path, temp_dir, hocr_filename)
      # Convert all PDF pages to images and OCR each page so overlay text is available
      # across the entire document, not just page one.
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
      # pdftoppm converts all PDF pages to PNG files prefixed as page-*.png
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
          # Retry runs can find an already-attached HOCR file after an index failure.
          # Reindex here so OCR pointers are still written to Solr.
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
          derivative_type: 'hocr'
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
      filename.casecmp(Derivatives::ImagesToPdf::JOINED_PDF_FILENAME).zero?
    end

    def pdf_file_set?(file_set)
      mime_type = normalize_mime_type(file_set.original_file&.mime_type)
      filename = normalize_filename(file_set.original_file&.original_filename)

      mime_type.start_with?('application/pdf') || filename.end_with?('.pdf')
    end
  end
end
