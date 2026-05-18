# frozen_string_literal: true

redis_config = YAML.safe_load(
  ERB.new(IO.read(Rails.root.join("config", "redis.yml"))).result
)[Rails.env].with_indifferent_access

redis_url = "redis://#{redis_config[:host]}:#{redis_config[:port]}/0"

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url, password: redis_config[:password].presence }
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url, password: redis_config[:password].presence }
end
