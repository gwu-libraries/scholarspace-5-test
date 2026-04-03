# frozen_string_literal: true

require 'open3'

module ScholarspaceDerivativesServices
  module Concerns
    module OcrPdfGeneratable

      private

      def pdf_has_embedded_text?(pdf_path)
        stdout, _stderr, status = Open3.capture3('pdftotext', pdf_path, '-')
        return false unless status.success?

        stdout.to_s.gsub(/\s+/, '').present?
      rescue StandardError => e
        Rails.logger.warn("Unable to inspect PDF text layer for work #{@work.id}: #{e.class} #{e.message}")
        false
      end

      def generate_ocr_rendering_pdf(source_pdf_path:, ocr_output_path:)
        cmd = [
          'ocrmypdf',
          '--jobs', '1',
          '--skip-text',
          '--optimize', '1',
          source_pdf_path,
          ocr_output_path
        ]

        _stdout, stderr, status = Open3.capture3(*cmd)
        return true if status.success?

        Rails.logger.warn("OCRmyPDF failed for work #{@work.id}: #{stderr.to_s.strip}")
        false
      rescue StandardError => e
        Rails.logger.warn("Unable to run OCRmyPDF for work #{@work.id}: #{e.class} #{e.message}")
        false
      end

      def generate_ocr_rendering_pdf!(source_pdf_path:, ocr_output_path:, error_message:)
        return if generate_ocr_rendering_pdf(source_pdf_path: source_pdf_path, ocr_output_path: ocr_output_path)

        raise error_message
      end
    end
  end
end