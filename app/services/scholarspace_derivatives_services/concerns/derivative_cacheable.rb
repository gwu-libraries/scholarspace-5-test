# frozen_string_literal: true

require 'open3'

module ScholarspaceDerivativesServices
  module Concerns
    module DerivativeCacheable
      extend ActiveSupport::Concern

      private

      def cache_derivative_file(file_path:, file_set:, derivative_type: 'derivative')
        return unless File.exist?(file_path)
        optimized_path = optimize_derivative_for_cache(file_path, derivative_type)

        DerivativeCacheService.instance.store_from_path(
          file_identifier: file_set.original_file.file_identifier,
          original_filename: file_set.original_file.original_filename,
          source_path: optimized_path
        )
      end

      def optimize_derivative_for_cache(file_path, derivative_type)
        return file_path unless File.exist?(file_path)

        case derivative_type
        when 'pdf'
          optimize_pdf_for_web(file_path)
        else
          file_path
        end
      end

      def optimize_pdf_for_web(pdf_path)
        optimized_path = "#{pdf_path}.optimized.pdf"
        cmd = [
          'gs',
          '-q',
          '-dNOPAUSE',
          '-dBATCH',
          '-dSAFER',
          '-sDEVICE=pdfwrite',
          '-dCompatibilityLevel=1.4',
          '-dPDFSETTINGS=/ebook',
          '-dEmbedAllFonts=true',
          '-dSubsetFonts=true',
          "-sOutputFile=#{optimized_path}",
          pdf_path
        ]

        _stdout, stderr, status = Open3.capture3(*cmd)
        if status.success? && File.exist?(optimized_path)
          FileUtils.mv(optimized_path, pdf_path)
          pdf_path
        else
          Rails.logger.warn("PDF optimization failed for #{pdf_path}: #{stderr}")
          pdf_path
        end
      rescue StandardError => e
        Rails.logger.warn("Error optimizing PDF #{pdf_path}: #{e.message}")
        pdf_path
      end
    end
  end
end
