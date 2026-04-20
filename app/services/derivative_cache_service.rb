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

  def cached?(file_identifier:, original_filename: nil)
    File.exist?(path_for(file_identifier, original_filename))
  end

  def store_from_path(file_identifier:, original_filename:, source_path:)
    cache_path = path_for(file_identifier, original_filename)
    FileUtils.mkdir_p(File.dirname(cache_path))
    FileUtils.copy_file(source_path, cache_path)
    cache_path
  end

  def store_from_storage(file_identifier:, original_filename:)
    cache_path = path_for(file_identifier, original_filename)
    FileUtils.mkdir_p(File.dirname(cache_path))

    storage_file = Valkyrie::StorageAdapter.find_by(id: file_identifier)
    File.open(cache_path, 'wb') do |destination_io|
      IO.copy_stream(storage_file.stream, destination_io)
    end

    cache_path
  end

  private

  def path_for(file_identifier, filename)
    extension = File.extname(filename.to_s).downcase
    extension = '.bin' if extension.empty?
    digest = Digest::SHA256.hexdigest(file_identifier.to_s)
    File.join(@cache_root, digest[0, 2], "#{digest}#{extension}")
  end
end
