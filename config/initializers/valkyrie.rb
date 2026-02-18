# frozen_string_literal: true

require 'faraday/multipart'

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
          ENV.fetch('FEDORA_URL') { 'http://localhost:8080/fcrepo/rest' }
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
          ENV.fetch('FEDORA_URL') { 'http://localhost:8080/fcrepo/rest' }
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
