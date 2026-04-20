# frozen_string_literal: true

require 'open3'
require 'fileutils'
require 'thread'

module ScholarspaceDerivativesServices
  class PdfTextExtractionService
    include Concerns::FileSetAttachable
    include Concerns::HocrGeneratable
    include Concerns::HocrMergeable
    include Concerns::DerivativeCacheable

    def initialize(work)
      @work = work
    end

    def call
      pdf_file_sets = find_pdf_file_sets_needing_extraction
      log_pdf_extraction(:info, event: 'call_start', pdf_targets_count: pdf_file_sets.size)
      return if pdf_file_sets.empty?

      pdf_file_sets.each { |file_set| process_pdf(file_set) }
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
      expected_hocr_filename = expected_hocr_filename_for(pdf_file_set)
      member_file_sets.find do |fs|
        fs.original_file&.original_filename.to_s == expected_hocr_filename
      end
    end

    def expected_hocr_filename_for(pdf_file_set)
      original_filename = pdf_file_set.original_file.original_filename.to_s
      base_name = File.basename(original_filename, File.extname(original_filename))
      "#{base_name}_HOCR.hocr"
    end

    def process_pdf(pdf_file_set)
      source_filename = pdf_file_set.original_file&.original_filename.to_s
      log_pdf_extraction(
        :info,
        event: 'process_pdf_start',
        source_file_set_id: pdf_file_set.id.to_s,
        source_filename: source_filename
      )

      temp_dir = Dir.mktmpdir('pdf_extraction_')
      begin
        pdf_path = fetch_pdf_file(pdf_file_set, temp_dir)
        unless pdf_path
          log_pdf_extraction(
            :warn,
            event: 'process_pdf_halted',
            source_file_set_id: pdf_file_set.id.to_s,
            source_filename: source_filename,
            failure_stage: 'fetch_pdf',
            reason: 'pdf_fetch_failed'
          )
          return
        end

        hocr_filename = expected_hocr_filename_for(pdf_file_set)
        hocr_path = extract_hocr_for_pdf(pdf_path, temp_dir, hocr_filename)
        unless hocr_path
          log_pdf_extraction(
            :warn,
            event: 'process_pdf_halted',
            source_file_set_id: pdf_file_set.id.to_s,
            source_filename: source_filename,
            failure_stage: 'extract_hocr',
            reason: 'hocr_extract_failed'
          )
          return
        end

        unless File.exist?(hocr_path)
          log_pdf_extraction(
            :warn,
            event: 'process_pdf_halted',
            source_file_set_id: pdf_file_set.id.to_s,
            source_filename: source_filename,
            failure_stage: 'extract_hocr',
            reason: 'hocr_file_missing_after_extract',
            hocr_path: hocr_path
          )
          return
        end

        file_set = attach_hocr_to_work(hocr_path, pdf_file_set)
        if file_set
          log_pdf_extraction(
            :info,
            event: 'process_pdf_complete',
            source_file_set_id: pdf_file_set.id.to_s,
            source_filename: source_filename,
            attached_hocr_file_set_id: file_set.id.to_s,
            attached_hocr_filename: File.basename(hocr_path)
          )
        else
          log_pdf_extraction(
            :warn,
            event: 'process_pdf_halted',
            source_file_set_id: pdf_file_set.id.to_s,
            source_filename: source_filename,
            failure_stage: 'attach_hocr',
            reason: 'hocr_attach_skipped_or_failed',
            hocr_filename: File.basename(hocr_path)
          )
        end
      ensure
        FileUtils.rm_rf(temp_dir) if File.exist?(temp_dir)
      end
    end

    def fetch_pdf_file(file_set, temp_dir)
      pdf_path = File.join(temp_dir, 'document.pdf')
      io = Hyrax.storage_adapter.find_by(id: file_set.original_file.file_identifier)

      File.open(pdf_path, 'wb') do |destination_io|
        IO.copy_stream(io.stream, destination_io)
      end

      cache_derivative_file(
        file_path: pdf_path,
        file_set: file_set,
        derivative_type: 'pdf'
      )

      pdf_path
    rescue StandardError => e
      log_pdf_extraction(
        :warn,
        event: 'fetch_pdf_failed',
        source_file_set_id: file_set.id.to_s,
        source_filename: file_set.original_file&.original_filename.to_s,
        error_class: e.class.to_s,
        error_message: e.message
      )
      nil
    end

    def extract_hocr_for_pdf(pdf_path, temp_dir, hocr_filename)
      merged_hocr_path = File.join(temp_dir, hocr_filename)

      # Convert all PDF pages to images and OCR each page so overlay text is available
      # across the entire document, not just page one.
      image_paths = convert_pdf_to_images(pdf_path, temp_dir)
      return nil if image_paths.empty?

      hocr_pages_dir = File.join(temp_dir, 'hocr_pages')
      FileUtils.mkdir_p(hocr_pages_dir)

      hocr_paths = generate_hocr_files_in_parallel(image_paths: image_paths, hocr_pages_dir: hocr_pages_dir)
      return nil if hocr_paths.empty?

      @working_dir = temp_dir
      @joined_hocr_filename = hocr_filename
      merged_path = merge_hocr_files(hocr_paths)
      return nil unless merged_path && File.exist?(merged_path)

      log_pdf_extraction(
        :info,
        event: 'extract_hocr_success',
        pdf_path: pdf_path,
        image_count: image_paths.size,
        hocr_path: merged_path
      )
      merged_path
    rescue StandardError => e
      log_pdf_extraction(
        :warn,
        event: 'extract_hocr_failed',
        pdf_path: pdf_path,
        hocr_path: merged_hocr_path,
        error_class: e.class.to_s,
        error_message: e.message
      )
      nil
    end

    def convert_pdf_to_images(pdf_path, temp_dir)
      output_prefix = File.join(temp_dir, 'page')
      # pdftoppm converts all PDF pages to PNG files prefixed as page-*.png
      cmd = ['pdftoppm', '-png', pdf_path, output_prefix]
      _stdout, stderr, status = Open3.capture3(*cmd)

      unless status.success?
        log_pdf_extraction(
          :warn,
          event: 'convert_pdf_to_images_failed',
          pdf_path: pdf_path,
          command: cmd.join(' '),
          error_message: stderr.to_s.strip
        )
        return []
      end

      image_paths = Dir.glob(File.join(temp_dir, 'page-*.png')).sort
      if image_paths.any?
        log_pdf_extraction(
          :info,
          event: 'convert_pdf_to_images_success',
          pdf_path: pdf_path,
          image_count: image_paths.size
        )
        image_paths
      else
        log_pdf_extraction(
          :warn,
          event: 'convert_pdf_to_images_missing_output',
          pdf_path: pdf_path,
          expected_glob: File.join(temp_dir, 'page-*.png')
        )
        []
      end
    rescue StandardError => e
      log_pdf_extraction(
        :warn,
        event: 'convert_pdf_to_images_error',
        pdf_path: pdf_path,
        error_class: e.class.to_s,
        error_message: e.message
      )
      []
    end

    def generate_hocr_files_in_parallel(image_paths:, hocr_pages_dir:)
      ocr_workers = [2, image_paths.length].min
      queue = Queue.new
      image_paths.each_with_index { |image_path, index| queue << [index, image_path] }
      hocr_paths = Array.new(image_paths.length)
      errors = Queue.new

      threads = Array.new(ocr_workers) do
        Thread.new do
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
      end

      threads.each(&:join)
      raise errors.pop unless errors.empty?

      hocr_paths.compact
    end

    def joined_hocr_filename
      @joined_hocr_filename || 'merged_HOCR.hocr'
    end

    def attach_hocr_to_work(hocr_path, source_pdf_file_set)
      user = User.find_by(email: @work.depositor)
      unless user
        log_pdf_extraction(
          :warn,
          event: 'attach_hocr_skipped',
          reason: 'depositor_user_not_found',
          depositor: @work.depositor,
          hocr_filename: File.basename(hocr_path)
        )
        return
      end

      filename = File.basename(hocr_path)
      if file_set_attached_with_name?(filename)
        log_pdf_extraction(
          :info,
          event: 'attach_hocr_skipped',
          reason: 'hocr_already_attached',
          hocr_filename: filename
        )
        return
      end

      file_set = attach_single_file_to_work(
        file_path: hocr_path,
        user: user,
        service_file: true,
        source_file_set: source_pdf_file_set
      )

      if file_set
        reindex_work_and_file_set(file_set)
        # Cache the hOCR derivative for fast future downloads
        cache_derivative_file(
          file_path: hocr_path,
          file_set: file_set,
          derivative_type: 'hocr'
        )
        log_pdf_extraction(
          :info,
          event: 'attach_hocr_success',
          attached_hocr_file_set_id: file_set.id.to_s,
          hocr_filename: filename,
          source_file_set_id: source_pdf_file_set.id.to_s
        )
      end

      file_set
    end

    def log_pdf_extraction(level, payload)
      base_payload = {
        service: self.class.name,
        work_id: @work.id.to_s
      }

      logger = Rails.logger
      logger.public_send(level, base_payload.merge(payload).to_json)
    end

    def member_file_sets
      @member_file_sets ||= @work.member_ids.map { |id| Hyrax.query_service.find_by(id: id) }
    end

    def reindex_work_and_file_set(file_set)
      Hyrax.persister.save(resource: @work)
      Hyrax.index_adapter.save(resource: @work)
      Hyrax.index_adapter.save(resource: file_set)
    end

    def extraction_target_pdf_file_set?(file_set)
      return false unless pdf_file_set?(file_set)
      return true unless file_set.service_file

      image_joined_pdf_file_set?(file_set)
    end

    def image_joined_pdf_file_set?(file_set)
      filename = file_set.original_file&.original_filename.to_s
      filename.casecmp(ScholarspaceDerivativesServices::ImagesToPdfDerivativesService::JOINED_PDF_FILENAME).zero?
    end

    def pdf_file_set?(file_set)
      mime_type = file_set.original_file&.mime_type.to_s.downcase
      filename = file_set.original_file&.original_filename.to_s.downcase

      mime_type.start_with?('application/pdf') || filename.end_with?('.pdf')
    end
  end
end
