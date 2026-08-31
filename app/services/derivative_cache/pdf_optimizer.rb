# frozen_string_literal: true

require 'fileutils'
require 'open3'
require 'timeout'

module DerivativeCache
  class PdfOptimizer
    include Constants::DerivativeTypeConstants

    TIMEOUT_SECONDS = DerivativeJobSettings.seconds(:pdf_optimization, :timeout_seconds)

    def optimize(file_path, derivative_type)
      return file_path unless File.exist?(file_path)
      return file_path unless [DERIVATIVE_TYPE_PDF, DERIVATIVE_TYPE_PDF_DERIVATIVE].include?(derivative_type)

      optimize_for_web(file_path)
    end

    private

    def optimize_for_web(pdf_path)
      optimized_path = "#{pdf_path}.optimized.pdf"
      _stdout, stderr, status = Timeout.timeout(TIMEOUT_SECONDS) do
        Open3.capture3(*command_for(pdf_path, optimized_path))
      end

      if status.success? && File.exist?(optimized_path)
        FileUtils.mv(optimized_path, pdf_path)
      else
        Rails.logger.warn("PDF optimization failed for #{pdf_path}: #{stderr}")
      end

      pdf_path
    rescue Timeout::Error
      Rails.logger.warn("PDF optimization timed out for #{pdf_path} after #{TIMEOUT_SECONDS}s")
      pdf_path
    rescue StandardError => error
      Rails.logger.warn("Error optimizing PDF #{pdf_path}: #{error.message}")
      pdf_path
    ensure
      FileUtils.rm_f(optimized_path) if defined?(optimized_path) && File.exist?(optimized_path)
    end

    def command_for(pdf_path, optimized_path)
      [
        'gs', '-q', '-dNOPAUSE', '-dBATCH', '-dSAFER', '-sDEVICE=pdfwrite',
        '-dCompatibilityLevel=1.4', '-dPDFSETTINGS=/default', '-dDetectDuplicateImages=true',
        '-dCompressFonts=true', '-dColorImageDownsampleType=/Bicubic',
        '-dColorImageResolution=150', '-dGrayImageDownsampleType=/Bicubic',
        '-dGrayImageResolution=150', '-dMonoImageDownsampleType=/Subsample',
        '-dMonoImageResolution=300', '-dEmbedAllFonts=true', '-dSubsetFonts=true',
        "-sOutputFile=#{optimized_path}", pdf_path
      ]
    end
  end
end