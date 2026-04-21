# Defines a custom logger for use in logging to a file during automated Bulkrax ingests
require 'json'

class BulkraxImportLogger
  class << self

    def info(*args)
      new.info(*args)
    end

    def debug(*args)
      new.debug(*args)
    end

  end

  delegate :info, :debug, to: :logger

  attr_reader :logger

  def initialize
    @logger = ActiveSupport::Logger.new(Rails.root.join("log/bulkrax_imports.log"))
    @logger.formatter = proc do |severity, datetime, progname, msg|
      {timestamp: datetime, message: msg}.to_json + "\n"
    end
  end
end
