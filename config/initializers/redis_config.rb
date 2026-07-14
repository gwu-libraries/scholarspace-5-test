# frozen_string_literal: true
require "redis"
require "connection_pool"
config =
  YAML.safe_load(
    ERB.new(IO.read(Rails.root.join("config", "redis.yml"))).result
  )[
    Rails.env
  ].with_indifferent_access

size = ENV.fetch("HYRAX_REDIS_POOL_SIZE", 5)
timeout = ENV.fetch("HYRAX_REDIS_TIMEOUT", 5)

redis_options = config.merge(
  url: ENV['REDIS_URL'].presence,
  connect_timeout: ENV.fetch('HYRAX_REDIS_CONNECT_TIMEOUT', 5).to_f,
  read_timeout: ENV.fetch('HYRAX_REDIS_READ_TIMEOUT', 5).to_f,
  write_timeout: ENV.fetch('HYRAX_REDIS_WRITE_TIMEOUT', 5).to_f,
  reconnect_attempts: ENV.fetch('HYRAX_REDIS_RECONNECT_ATTEMPTS', 3).to_i
).compact

Hyrax.config.redis_connection =
  ConnectionPool::Wrapper.new(size: size, timeout: timeout) do
    Redis.new(redis_options)
  end
