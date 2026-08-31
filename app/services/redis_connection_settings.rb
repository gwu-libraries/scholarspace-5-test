# frozen_string_literal: true

module RedisConnectionSettings
  module_function

  def url
    ENV['REDIS_URL'].presence || "redis://#{host}:#{port}/0"
  end

  def pool
    @pool ||= ConnectionPool.new(
      size: ENV.fetch('REDLOCK_POOL_SIZE', 5).to_i,
      timeout: ENV.fetch('REDLOCK_POOL_TIMEOUT', 5).to_i
    ) { Redis.new(url: url) }
  end

  def config
    @config ||= YAML.safe_load(
      ERB.new(IO.read(Rails.root.join('config', 'redis.yml'))).result
    ).fetch(Rails.env, {}).to_h.with_indifferent_access
  end

  def host
    config[:host].presence || 'localhost'
  end

  def port
    config[:port].presence || 6379
  end
end
