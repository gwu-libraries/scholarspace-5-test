# frozen_string_literal: true

require "sidekiq/api"

redis_config = YAML.safe_load(
  ERB.new(IO.read(Rails.root.join("config", "redis.yml"))).result
)[Rails.env].with_indifferent_access

redis_url = ENV['REDIS_URL'].presence || "redis://#{redis_config[:host]}:#{redis_config[:port]}/0"

def sidekiq_redis_options(redis_url:, redis_password:)
  {
    url: redis_url,
    password: redis_password,
    network_timeout: ENV.fetch('SIDEKIQ_REDIS_NETWORK_TIMEOUT', 10).to_i,
    pool_timeout: ENV.fetch('SIDEKIQ_REDIS_POOL_TIMEOUT', 10).to_i,
    connect_timeout: ENV.fetch('SIDEKIQ_REDIS_CONNECT_TIMEOUT', 5).to_f,
    read_timeout: ENV.fetch('SIDEKIQ_REDIS_READ_TIMEOUT', 5).to_f,
    write_timeout: ENV.fetch('SIDEKIQ_REDIS_WRITE_TIMEOUT', 5).to_f,
    reconnect_attempts: ENV.fetch('SIDEKIQ_REDIS_RECONNECT_ATTEMPTS', 3).to_i
  }
end

QUEUE_PRESSURE_LOG_INTERVAL_SECONDS = 20
QUEUE_LATENCY_THRESHOLD_SECONDS = 120.0
QUEUE_DEPTH_THRESHOLD = 25

Sidekiq.configure_server do |config|
  config.redis = sidekiq_redis_options(
    redis_url: redis_url,
    redis_password: redis_config[:password].presence
  )

  pressure_check_stop = false

  config.on(:quiet) { pressure_check_stop = true }
  config.on(:shutdown) { pressure_check_stop = true }

  config.on(:startup) do
    only_audio_transcript = ENV['SIDEKIQ_ONLY_AUDIO_TRANSCRIPT'] == 'true'
    only_ocr_text_extraction = ENV['SIDEKIQ_ONLY_OCR_TEXT_EXTRACTION'] == 'true' || ENV['SIDEKIQ_ONLY_PDF_TEXT_EXTRACTION'] == 'true'
    only_derivatives = ENV['SIDEKIQ_ONLY_DERIVATIVES'] == 'true'
    only_thumbnail = ENV['SIDEKIQ_ONLY_THUMBNAIL'] == 'true'

    profile = if only_audio_transcript
                'audio_transcript'
              elsif only_ocr_text_extraction
                'pdf_text_derivatives'
              elsif only_thumbnail
                'thumbnail_derivatives'
              elsif only_derivatives
                'image_assembly_derivatives'
              else
                'default_core'
              end

    queue_names = Array(config[:queues]).map { |entry| Array(entry).first.to_s }.reject(&:empty?).uniq

    Rails.logger.info(
      "sidekiq_profile_start profile=#{profile} queues=#{queue_names.join(',')} " \
      "only_audio_transcript=#{only_audio_transcript} " \
      "only_ocr_text_extraction=#{only_ocr_text_extraction} " \
      "only_derivatives=#{only_derivatives} only_thumbnail=#{only_thumbnail}"
    )

    Thread.new do
      loop do
        break if pressure_check_stop

        begin
          queue_snapshots = queue_names.map do |queue_name|
            queue = Sidekiq::Queue.new(queue_name)
            {
              name: queue_name,
              latency_seconds: queue.latency.to_f,
              depth: queue.size.to_i
            }
          end

          max_latency_queue = queue_snapshots.max_by { |snapshot| snapshot[:latency_seconds] }
          max_latency_seconds = max_latency_queue ? max_latency_queue[:latency_seconds] : 0.0
          total_depth = queue_snapshots.sum { |snapshot| snapshot[:depth] }

          if max_latency_seconds >= QUEUE_LATENCY_THRESHOLD_SECONDS
            Rails.logger.warn(
              "queue_latency_high queue=#{max_latency_queue[:name]} " \
              "latency_seconds=#{max_latency_seconds.round(2)} " \
              "threshold_seconds=#{QUEUE_LATENCY_THRESHOLD_SECONDS} total_depth=#{total_depth}"
            )
          end

          if total_depth >= QUEUE_DEPTH_THRESHOLD
            Rails.logger.warn(
              "queue_depth_high total_depth=#{total_depth} " \
              "threshold_depth=#{QUEUE_DEPTH_THRESHOLD} " \
              "max_latency_seconds=#{max_latency_seconds.round(2)}"
            )
          end
        rescue StandardError => e
          Rails.logger.error("queue_pressure_check_failed error_class=#{e.class} message=#{e.message}")
        ensure
          sleep(QUEUE_PRESSURE_LOG_INTERVAL_SECONDS)
        end
      end
    end
  end
end

Sidekiq.configure_client do |config|
  config.redis = sidekiq_redis_options(
    redis_url: redis_url,
    redis_password: redis_config[:password].presence
  )
end
