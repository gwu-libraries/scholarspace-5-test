# frozen_string_literal: true

class IngestRecoveryService
  DEFAULT_STALE_AFTER = 2.hours
  LOCK_KEY = 'ingest_recovery:running'
  LOCK_TIMEOUT_SECONDS = 600

  def self.call(stale_after: DEFAULT_STALE_AFTER)
    new.call(stale_after: stale_after)
  end

  def call(stale_after: DEFAULT_STALE_AFTER)
    return 0 unless acquire_lock

    requeued = 0

    stale_uploads(stale_after).find_each do |uploaded_file|
      next unless retryable?(uploaded_file)

      ValkyrieIngestJob.perform_later(uploaded_file)
      uploaded_file.touch
      Rails.logger.warn("ingest_recovery_requeued uploaded_file_id=#{uploaded_file.id} file_set_id=#{uploaded_file.file_set_uri}")
      requeued += 1
    rescue StandardError => error
      Rails.logger.error("ingest_recovery_failed uploaded_file_id=#{uploaded_file.id} error_class=#{error.class} error_message=#{error.message}")
    end

    requeued
  end

  private

  def stale_uploads(stale_after)
    Hyrax::UploadedFile
      .where.not(file_set_uri: [nil, ''])
      .where('updated_at < ?', stale_after.ago)
  end

  def acquire_lock
    Sidekiq.redis do |redis|
      redis.set(LOCK_KEY, 1, nx: true, ex: LOCK_TIMEOUT_SECONDS)
    end
  end

  def retryable?(uploaded_file)
    file_set = Hyrax.query_service.find_by(id: Valkyrie::ID.new(uploaded_file.file_set_uri))
    return false if file_set.original_file.present?

    upload_available?(uploaded_file)
  rescue Valkyrie::Persistence::ObjectNotFoundError
    Rails.logger.error("ingest_recovery_missing_file_set uploaded_file_id=#{uploaded_file.id} file_set_id=#{uploaded_file.file_set_uri}")
    false
  end

  def upload_available?(uploaded_file)
    path = uploaded_file.uploader.file&.path
    return true if path.present? && File.exist?(path)

    Rails.logger.error("ingest_recovery_missing_upload uploaded_file_id=#{uploaded_file.id} file_set_id=#{uploaded_file.file_set_uri}")
    false
  end
end
