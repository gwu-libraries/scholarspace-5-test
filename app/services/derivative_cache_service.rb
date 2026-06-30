# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'open3'
require 'timeout'

class DerivativeCacheService
  include DerivativeTypeConstants
  include FileOperations
  CACHE_ROOT = '/app/scholarspace/tmp/cache/derivatives'
  FALLBACK_CACHE_ROOT = '/tmp/scholarspace-cache/derivatives'
  PDF_OPTIMIZE_TIMEOUT_SECONDS = 120

  def self.instance
    @instance ||= new
  end

  def initialize(cache_root: CACHE_ROOT)
    @cache_root = ensure_writable_cache_root(cache_root)
  end

  def fetch_stream(file_identifier:, original_filename: nil)
    cache_path = path_for(file_identifier, original_filename)
    return nil unless File.exist?(cache_path)

    File.open(cache_path, 'rb')
  end

  def cached?(file_identifier:, original_filename: nil)
    File.exist?(path_for(file_identifier, original_filename))
  end

  def store_from_path(file_identifier:, original_filename:, source_path:)
    cache_path = path_for(file_identifier, original_filename)
    ensure_directory_exists(File.dirname(cache_path))
    FileUtils.copy_file(source_path, cache_path)
    cache_path
  end

  def store_derivative_from_path(file_identifier:, original_filename:, source_path:, derivative_type: DERIVATIVE_TYPE_DEFAULT)
    return nil unless File.exist?(source_path)
    return path_for(file_identifier, original_filename) if cached?(file_identifier: file_identifier, original_filename: original_filename)

    optimized_path = optimize_derivative_for_cache(source_path, derivative_type)

    store_from_path(
      file_identifier: file_identifier,
      original_filename: original_filename,
      source_path: optimized_path
    )
  end

  def store_from_storage(file_identifier:, original_filename:)
    cache_path = path_for(file_identifier, original_filename)
    ensure_directory_exists(File.dirname(cache_path))

    storage_file = Valkyrie::StorageAdapter.find_by(id: file_identifier)
    File.open(cache_path, 'wb') do |destination_io|
      IO.copy_stream(storage_file.stream, destination_io)
    end

    cache_path
  end

  private

  def optimize_derivative_for_cache(file_path, derivative_type)
    return file_path unless File.exist?(file_path)

    case derivative_type
    when DERIVATIVE_TYPE_PDF, DERIVATIVE_TYPE_PDF_DERIVATIVE
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
      '-dPDFSETTINGS=/default',
      '-dDetectDuplicateImages=true',
      '-dCompressFonts=true',
      '-dColorImageDownsampleType=/Bicubic',
      '-dColorImageResolution=150',
      '-dGrayImageDownsampleType=/Bicubic',
      '-dGrayImageResolution=150',
      '-dMonoImageDownsampleType=/Subsample',
      '-dMonoImageResolution=300',
      '-dEmbedAllFonts=true',
      '-dSubsetFonts=true',
      "-sOutputFile=#{optimized_path}",
      pdf_path
    ]

    _stdout = nil
    stderr = nil
    status = nil
    Timeout.timeout(PDF_OPTIMIZE_TIMEOUT_SECONDS) do
      _stdout, stderr, status = Open3.capture3(*cmd)
    end

    if status.success? && File.exist?(optimized_path)
      FileUtils.mv(optimized_path, pdf_path)
      pdf_path
    else
      Rails.logger.warn("PDF optimization failed for #{pdf_path}: #{stderr}")
      pdf_path
    end
  rescue Timeout::Error
    Rails.logger.warn("PDF optimization timed out for #{pdf_path} after #{PDF_OPTIMIZE_TIMEOUT_SECONDS}s")
    pdf_path
  rescue StandardError => e
    Rails.logger.warn("Error optimizing PDF #{pdf_path}: #{e.message}")
    pdf_path
  ensure
    FileUtils.rm_f(optimized_path) if defined?(optimized_path) && File.exist?(optimized_path)
  end

  def path_for(file_identifier, filename)
    extension = File.extname(filename.to_s).downcase
    extension = '.bin' if extension.empty?
    digest = Digest::SHA256.hexdigest(file_identifier.to_s)
    File.join(@cache_root, digest[0, 2], "#{digest}#{extension}")
  end

  def ensure_writable_cache_root(path)
    ensure_directory_exists(path)
    return path if File.writable?(path)

    fallback = ENV.fetch('DERIVATIVES_CACHE_ROOT', FALLBACK_CACHE_ROOT)
    ensure_directory_exists(fallback)
    fallback
  rescue SystemCallError
    fallback = ENV.fetch('DERIVATIVES_CACHE_ROOT', FALLBACK_CACHE_ROOT)
    ensure_directory_exists(fallback)
    fallback
  end
end
