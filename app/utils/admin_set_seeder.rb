class AdminSetSeeder
  class << self
    attr_accessor :logger

    def generate_required_seeds(logger: Logger.new(STDOUT))
      @logger = logger

      logger.info("Adding required collections...")

      default_admin_set =
        Hyrax::AdminSetCreateService.find_or_create_default_admin_set
      logger.info "   #{default_admin_set.title.first} -- FOUND OR CREATED"
    end
  end
end
