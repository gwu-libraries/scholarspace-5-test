# frozen_string_literal: true

require 'socket'

module IngestLifecycleInstrumentation
  def perform(file, **options)
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    log_ingest_event('started', file: file)
    result = super
    log_ingest_event('completed', file: file, elapsed_seconds: elapsed_seconds(started_at))
    result
  rescue StandardError => error
    log_ingest_event(
      'failed',
      file: file,
      elapsed_seconds: elapsed_seconds(started_at),
      error_class: error.class.name,
      error_message: error.message
    )
    raise
  end

  private

  def elapsed_seconds(started_at)
    (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at).round(3)
  end

  def log_ingest_event(event, file:, **context)
    details = {
      event: event,
      uploaded_file_id: file.id,
      file_set_id: file.file_set_uri,
      filename: file.file.to_s,
      hostname: Socket.gethostname
    }.merge(context)
    details[:job_id] = job_id if respond_to?(:job_id)
    details[:provider_job_id] = provider_job_id if respond_to?(:provider_job_id)

    Rails.logger.public_send(event == 'failed' ? :error : :info, "valkyrie_ingest #{details.to_json}")
  end
end