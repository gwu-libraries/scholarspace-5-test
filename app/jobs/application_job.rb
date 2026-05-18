class ApplicationJob < ActiveJob::Base
  protected

  # Fetch a work by ID and execute a block with it; return early if work not found.
  # Useful for derivative jobs that operate on works:
  #   with_work(work_id: id) { |work| SomeService.new(work).call }
  def with_work(work_id:)
    work = Hyrax.query_service.find_by(id: work_id)
    yield(work) if work
  end
end
