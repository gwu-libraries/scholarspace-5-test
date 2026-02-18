# Defines a custom logger for use in logging to a file during automated Bulkrax ingests
class BulkraxImportLogger
  class << self

    def info(*args)
      new.info(*args)
    end
  end

  delegate :info, to: :logger

  attr_reader :logger

  def initialize
    @logger = ActiveSupport::Logger.new(Rails.root.join("log/bulkrax_imports.log"))
    @logger.formatter = ::Logger::Formatter.new
  end
end
