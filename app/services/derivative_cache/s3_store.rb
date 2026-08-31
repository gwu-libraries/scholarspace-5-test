# frozen_string_literal: true

require 'aws-sdk-s3'
require 'stringio'

module DerivativeCache
  class S3Store
    def initialize(bucket:, prefix:, client: Aws::S3::Client.new)
      @bucket = bucket
      @prefix = prefix
      @client = client
    end

    def fetch_stream(file_identifier:, original_filename: nil)
      response = @client.get_object(bucket: @bucket, key: key_for(file_identifier, original_filename))
      StringIO.new(response.body.read)
    rescue Aws::S3::Errors::NoSuchKey, Aws::S3::Errors::NotFound
      nil
    end

    def cached?(file_identifier:, original_filename: nil)
      @client.head_object(bucket: @bucket, key: key_for(file_identifier, original_filename))
      true
    rescue Aws::S3::Errors::NotFound
      false
    end

    def cache_location(file_identifier:, original_filename: nil)
      key_for(file_identifier, original_filename)
    end

    def store_from_path(file_identifier:, original_filename:, source_path:)
      key = key_for(file_identifier, original_filename)
      File.open(source_path, 'rb') do |file|
        @client.put_object(bucket: @bucket, key: key, body: file)
      end
      key
    end

    def store_from_storage(file_identifier:, original_filename:)
      storage_file = Valkyrie::StorageAdapter.find_by(id: file_identifier)
      key = key_for(file_identifier, original_filename)
      @client.put_object(bucket: @bucket, key: key, body: storage_file.stream)
      key
    end

    private

    def key_for(file_identifier, original_filename)
      File.join(
        @prefix,
        CacheKey.relative_path(file_identifier: file_identifier, original_filename: original_filename)
      )
    end
  end
end