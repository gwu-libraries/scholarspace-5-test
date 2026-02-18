class BulkraxListener

  attr_accessor :event

  def on_object_failed_deposit(event)
    BulkraxImportLogger.info(event.inspect)
  end

  def on_object_deposited(event)
    BulkraxImportLogger.info(event.inspect)
  end

  def on_file_set_attached(event)
    BulkraxImportLogger.info(event.inspect)
  end

  def on_object_membership_updated(event)
    BulkraxImportLogger.info(event.inspect)
  end

  def on_object_metadata_updated(event)
    BulkraxImportLogger.info(event.inspect)
  end

  def on_file_characterized(event)
    BulkraxImportLogger.info(event.inspect)
  end

end
