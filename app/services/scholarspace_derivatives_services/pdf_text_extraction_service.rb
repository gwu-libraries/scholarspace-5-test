# frozen_string_literal: true

require 'open3'
require 'fileutils'

module ScholarspaceDerivativesServices
  class PdfTextExtractionService
    include Concerns::FileSetAttachable

    def initialize(work)
      @work = work
    end

    def call
      pdf_file_sets = find_pdf_file_sets_needing_extraction
      return if pdf_file_sets.empty?

      pdf_file_sets.each { |file_set| process_pdf(file_set) }
    end

    private

    def find_pdf_file_sets_needing_extraction
      member_file_sets.select do |file_set|
        # Only process PDFs that are original files (not derivatives)
        next false unless file_set.original_file&.mime_type.to_s == 'application/pdf'
        next false if file_set.service_file

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
      base_name = File.basename(original_filename, '.pdf')
      "#{base_name}_HOCR.hocr"
    end

    def process_pdf(pdf_file_set)
      temp_dir = Dir.mktmpdir('pdf_extraction_')
      begin
        pdf_path = fetch_pdf_file(pdf_file_set, temp_dir)
        return unless pdf_path && has_embedded_text?(pdf_path)

        hocr_filename = expected_hocr_filename_for(pdf_file_set)
        hocr_path = extract_pdf_text_to_hocr(pdf_path, temp_dir, hocr_filename)
        return unless hocr_path && File.exist?(hocr_path)

        attach_hocr_to_work(hocr_path, pdf_file_set)
      ensure
        FileUtils.rm_rf(temp_dir) if File.exist?(temp_dir)
      end
    end

    def fetch_pdf_file(file_set, temp_dir)
      pdf_path = File.join(temp_dir, 'document.pdf')
      io = Hyrax.storage_adapter.find_by(id: file_set.original_file.file_identifier)

      destination_io = File.open(pdf_path, 'wb')
      IO.copy_stream(io.stream, destination_io)
      destination_io.close

      pdf_path
    end

    def has_embedded_text?(pdf_path)
      stdout, _stderr, status = Open3.capture3('pdftotext', pdf_path, '-')
      return false unless status.success?

      stdout.to_s.gsub(/\s+/, '').present?
    rescue StandardError => e
      Rails.logger.warn("Unable to check PDF text for work #{@work.id}: #{e.class} #{e.message}")
      false
    end

    def extract_pdf_text_to_hocr(pdf_path, temp_dir, hocr_filename)
      output_stem = File.basename(hocr_filename, '.hocr')
      output_base = File.join(temp_dir, output_stem)
      hocr_path = "#{output_base}.hocr"

      # pdftohtml with -hocr flag extracts both text and layout as HOCR
      cmd = ['pdftohtml', '-hocr', pdf_path, output_base]
      _stdout, stderr, status = Open3.capture3(*cmd)

      unless status.success?
        Rails.logger.warn("pdftohtml extraction failed for work #{@work.id}: #{stderr.to_s.strip}")
        return nil
      end

      return hocr_path if File.exist?(hocr_path)

      Rails.logger.warn("pdftohtml did not generate HOCR file for work #{@work.id}")
      nil
    rescue StandardError => e
      Rails.logger.warn("Failed to extract PDF text to HOCR for work #{@work.id}: #{e.class} #{e.message}")
      nil
    end

    def attach_hocr_to_work(hocr_path, source_pdf_file_set)
      user = User.find_by(email: @work.depositor)
      return unless user

      filename = File.basename(hocr_path)
      return if file_set_attached_with_name?(filename)

      file_set = attach_single_file_to_work(
        file_path: hocr_path,
        user: user,
        service_file: true,
        source_file_set: source_pdf_file_set
      )

      if file_set
        Hyrax.persister.save(resource: @work)
        Hyrax.index_adapter.save(resource: @work)
        Hyrax.index_adapter.save(resource: file_set)
        Rails.logger.info("PdfTextExtractionService extracted HOCR from PDF for work #{@work.id}")
      end

      file_set
    end

    def member_file_sets
      @member_file_sets ||= @work.member_ids.map { |id| Hyrax.query_service.find_by(id: id) }
    end
  end
end
