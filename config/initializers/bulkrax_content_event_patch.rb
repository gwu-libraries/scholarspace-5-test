Rails.application.config.to_prepare do
  module ContentEventJobDecorator
    def log_user_event(depositor)
      # Patching with rescue from exception: depositor is nil for some reason on certain import scenarios --> @dolsysmith
      begin
        Hyrax.logger.debug("Event from ContentEventJob: #{event}")
        depositor.log_profile_event(event)
      rescue
        return
      end
    end
  end
  ContentEventJob.prepend ContentEventJobDecorator
end
