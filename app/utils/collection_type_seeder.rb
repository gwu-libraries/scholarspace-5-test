# frozen_string_literal: true

class CollectionTypeSeeder
  class << self
    attr_accessor :logger

    def generate_required_seeds(logger: Logger.new($stdout))
      @logger = logger

      logger.info('Adding required collection types...')

      as_ct = Hyrax::CollectionType.find_or_create_admin_set_type
      set_badge_color(as_ct, '#990000')
      logger.info("   #{as_ct.title} -- FOUND OR CREATED")

      user_ct = Hyrax::CollectionType.find_or_create_default_collection_type
      set_badge_color(user_ct, '#0099cc')
      logger.info("   #{user_ct.title} -- FOUND OR CREATED")
    end

    private

    def set_badge_color(collection_type, badge_color = nil)
      collection_type.badge_color = badge_color
      collection_type.save
    end
  end
end
