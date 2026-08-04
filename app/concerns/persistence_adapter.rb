# frozen_string_literal: true

# Provides methods for persisting and indexing Valkyrie resources.
# Removes need to reindex after saving, which is just obnoxious
# this should be handled by the valkyrie adapter, but it currently doesn't seem to be done automatically
module PersistenceAdapter
  # Save a resource to both persistence and index adapters
  def save_and_index(resource)
    saved = Hyrax.persister.save(resource: resource)
    Hyrax.index_adapter.save(resource: saved)
    saved
  end

  # Save multiple resources to index adapter
  def index_resources(resources)
    Array(resources).each { |resource| Hyrax.index_adapter.save(resource: resource) }
  end
end
