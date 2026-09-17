# frozen_string_literal: true

require 'faraday/multipart'

fedora_open_timeout = ENV.fetch('FEDORA_OPEN_TIMEOUT_SECONDS', 60).to_i
fedora_request_timeout = ENV.fetch('FEDORA_TIMEOUT_SECONDS', 14_400).to_i
fedora_read_timeout = ENV.fetch('FEDORA_READ_TIMEOUT_SECONDS', fedora_request_timeout).to_i
fedora_write_timeout = ENV.fetch('FEDORA_WRITE_TIMEOUT_SECONDS', fedora_request_timeout).to_i

Hyrax.config.fedora_connection_builder = lambda do |url|
  Faraday.new(url) do |connection|
    connection.request :multipart
    connection.request :url_encoded
    connection.options.open_timeout = fedora_open_timeout
    connection.options.timeout = fedora_request_timeout
    connection.options.read_timeout = fedora_read_timeout if connection.options.respond_to?(:read_timeout=)
    connection.options.write_timeout = fedora_write_timeout if connection.options.respond_to?(:write_timeout=)
    connection.adapter Faraday.default_adapter
  end
end

# require "shrine/storage/s3"
# require "valkyrie/storage/shrine"
# require "valkyrie/shrine/checksum/s3"

# database = ENV.fetch("METADATA_DB_NAME", "nurax_pg_metadata")
# Rails.logger.info "Establishing connection to postgresql on: " \
#                   "#{ENV["DB_HOST"]}:#{ENV["DB_PORT"]}.\n" \
#                   "Using database: #{database}."
# connection = Sequel.connect(
#   user: ENV["DB_USERNAME"],
#   password: ENV["DB_PASSWORD"],
#   host: ENV["DB_HOST"],
#   port: ENV["DB_PORT"],
#   database: database,
#   max_connections: ENV.fetch("DB_POOL", 5),
#   pool_timeout: ENV.fetch("DB_TIMEOUT", 5000),
#   adapter: :postgres
# )
#
# Valkyrie::MetadataAdapter
#   .register(Valkyrie::Sequel::MetadataAdapter.new(connection: connection),
#             :nurax_pg_metadata_adapter)
# Valkyrie::MetadataAdapter.register(
#   Valkyrie::Persistence::Postgres::MetadataAdapter.new,
#   :pg_metadata
# )

Valkyrie::MetadataAdapter.register(
  Valkyrie::Persistence::Fedora::MetadataAdapter.new(
    connection:
      ::Ldp::Client.new(
        Hyrax.config.fedora_connection_builder.call(
          ENV.fetch('FEDORA_URL', 'http://localhost:8080/fcrepo/rest')
        )
      ),
    base_path: Rails.env, # sets to '/development' instead of '/dev'
    schema:
      Valkyrie::Persistence::Fedora::PermissiveSchema.new(
        Hyrax::SimpleSchemaLoader.new.permissive_schema_for_valkrie_adapter
      ),
    fedora_version: 6.5,
    fedora_pairtree_count: 4,
    fedora_pairtree_length: 2
  ),
  :fedora_metadata
)

Valkyrie::StorageAdapter.register(
  Valkyrie::Storage::Fedora.new(
    connection:
      ::Ldp::Client.new(
        Hyrax.config.fedora_connection_builder.call(
          ENV.fetch('FEDORA_URL', 'http://localhost:8080/fcrepo/rest')
        )
      ),
    base_path: Rails.env, # sets to '/development' instead of '/dev'
    fedora_version: 6.5,
    fedora_pairtree_count: 4,
    fedora_pairtree_length: 2
  ),
  :fedora_storage
)

Valkyrie.config.metadata_adapter = :fedora_metadata
Valkyrie.config.storage_adapter = :fedora_storage
Valkyrie.config.indexing_adapter = :solr_index
