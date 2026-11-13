# frozen_string_literal: true

Rails.application.config.to_prepare do
  ValkyrieIngestJob.prepend(Ingest::LifecycleInstrumentation) unless ValkyrieIngestJob < Ingest::LifecycleInstrumentation
end