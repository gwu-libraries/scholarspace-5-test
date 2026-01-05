# frozen_string_literal: true

class ValkyrieCreateDerivativesJob < Hyrax::ApplicationJob
  queue_as Hyrax.config.ingest_queue_name

  def perform(work_id)
    work = Hyrax.query_service.find_by(id: work_id)
    # Get the derivative service class from the work
    derivative_service = work.derivative_service_class.new(work)
    # Call create_derivatives on the service
    derivative_service.create_derivatives
  end

  private

  def reindex_parent(parent)
    return unless parent&.thumbnail_id == file_set.id
    Hyrax.logger.debug do
      "Reindexing #{parent.id} due to creation of thumbnail derivatives."
    end
    Hyrax.index_adapter.save(resource: parent)
  end
end
