# frozen_string_literal: true

require 'digest'

module DerivativeCache
  class CacheKey
    def self.relative_path(file_identifier:, original_filename:)
      extension = File.extname(original_filename.to_s).downcase
      extension = '.bin' if extension.empty?
      digest = Digest::SHA256.hexdigest(file_identifier.to_s)

      File.join(digest[0, 2], "#{digest}#{extension}")
    end
  end
end