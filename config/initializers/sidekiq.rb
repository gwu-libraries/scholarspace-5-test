# frozen_string_literal: true

require "sidekiq/api"

redis_config = YAML.safe_load(
  ERB.new(IO.read(Rails.root.join("config", "redis.yml"))).result
)[Rails.env].with_indifferent_access

redis_url = ENV['REDIS_URL'].presence || "redis://#{redis_config[:host]}:#{redis_config[:port]}/0"

def sidekiq_redis_options(redis_url:, redis_password:)
  {
    url: redis_url,
    password: redis_password
  }
end

worker_monitoring = YAML.safe_load(
  File.read(Rails.root.join('config/worker_settings.yml'))
).fetch('shared').fetch('monitoring').to_h do |name, value|
  number = Integer(value.to_s, 10)
  [name, number]
end
QUEUE_PRESSURE_LOG_INTERVAL_SECONDS = worker_monitoring.fetch('poll_interval_seconds')
QUEUE_LATENCY_THRESHOLD_SECONDS = worker_monitoring.fetch('latency_threshold_seconds').to_f
QUEUE_DEPTH_THRESHOLD = worker_monitoring.fetch('depth_threshold')

Sidekiq.configure_server do |config|
  config.redis = sidekiq_redis_options(
    redis_url: redis_url,
    redis_password: redis_config[:password].presence
  )

  pressure_check_stop = false

  config.on(:quiet) { pressure_check_stop = true }
  config.on(:shutdown) { pressure_check_stop = true }

  config.on(:startup) do
    pool = ENV.fetch('SIDEKIQ_WORKER_POOL', 'default')
    queue_names = Array(config[:queues]).map { |entry| Array(entry).first.to_s }.reject(&:empty?).uniq

    Rails.logger.info(
      "sidekiq_profile_start pool=#{pool} queues=#{queue_names.join(',')}"
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
