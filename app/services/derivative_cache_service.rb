# frozen_string_literal: true

require 'digest'
require 'fileutils'

class DerivativeCacheService
  CACHE_ROOT = '/.cache/derivatives'

  def self.instance
    @instance ||= new
  end

  def initialize(cache_root: CACHE_ROOT)
    @cache_root = cache_root
  end

  def fetch_stream(file_identifier:, original_filename: nil)
    cache_path = path_for(file_identifier, original_filename)
    return nil unless File.exist?(cache_path)

    File.open(cache_path, 'rb')
  end

  def store_from_path(file_identifier:, original_filename:, source_path:)
    cache_path = path_for(file_identifier, original_filename)
    FileUtils.mkdir_p(File.dirname(cache_path))
    FileUtils.copy_file(source_path, cache_path)
    cache_path
  end

  private

  def path_for(file_identifier, filename)
    extension = filename ? File.extname(filename.to_s).downcase : '.bin'
    digest = Digest::SHA256.hexdigest(file_identifier.to_s)
    File.join(@cache_root, digest[0, 2], "#{digest}#{extension}")
  end
end
