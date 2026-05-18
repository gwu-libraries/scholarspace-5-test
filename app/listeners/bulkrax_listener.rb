class BulkraxListener
  # Events to log for Bulkrax import tracking
  TRACKED_EVENTS = %i[
    on_object_failed_deposit
    on_object_deposited
    on_file_set_attached
    on_object_membership_updated
    on_object_metadata_updated
    on_file_characterized
  ].freeze

  TRACKED_EVENTS.each do |event_method|
    define_method(event_method) { |event| BulkraxImportLogger.info(event.inspect) }
  end
end
