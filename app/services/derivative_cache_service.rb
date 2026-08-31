# frozen_string_literal: true

class DerivativeCacheService
  include Constants::DerivativeTypeConstants
  include FileOperations
  CACHE_ROOT = '/app/scholarspace/tmp/cache/derivatives'
  FALLBACK_CACHE_ROOT = '/tmp/scholarspace-cache/derivatives'

  def self.instance
    @instance ||= new
  end

  def initialize(cache_root: CACHE_ROOT)
    @cache_root = ensure_writable_cache_root(cache_root)
    @store = build_store
    @pdf_optimizer = DerivativeCache::PdfOptimizer.new
  end

  def fetch_stream(file_identifier:, original_filename: nil)
    @store.fetch_stream(file_identifier: file_identifier, original_filename: original_filename)
  end

  def cached?(file_identifier:, original_filename: nil)
    @store.cached?(file_identifier: file_identifier, original_filename: original_filename)
  end

  def store_from_path(file_identifier:, original_filename:, source_path:)
    @store.store_from_path(
      file_identifier: file_identifier,
      original_filename: original_filename,
      source_path: source_path
    )
  end

  def store_derivative_from_path(file_identifier:, original_filename:, source_path:,
                                 derivative_type: DERIVATIVE_TYPE_DEFAULT)
    return nil unless File.exist?(source_path)
    return cache_location(file_identifier, original_filename) if cached?(file_identifier: file_identifier,
                                        original_filename: original_filename)

    optimized_path = @pdf_optimizer.optimize(source_path, derivative_type)

    store_from_path(
      file_identifier: file_identifier,
      original_filename: original_filename,
      source_path: optimized_path
    )
  end

  def store_from_storage(file_identifier:, original_filename:)
    @store.store_from_storage(file_identifier: file_identifier, original_filename: original_filename)
  end

  private

  def build_store
    bucket = ENV['S3_BUCKET_NAME'].presence
    return DerivativeCache::FilesystemStore.new(cache_root: @cache_root) unless bucket

    DerivativeCache::S3Store.new(
      bucket: bucket,
      prefix: ENV.fetch('S3_DERIVATIVE_CACHE_PREFIX', 'derivatives-cache').sub(%r{/\z}, '')
    )
  end

  def cache_location(file_identifier, original_filename)
    @store.cache_location(file_identifier: file_identifier, original_filename: original_filename)
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
