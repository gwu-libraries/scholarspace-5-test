# frozen_string_literal: true

require 'factory_bot_rails'

class TestHydraGroupService
  ##
  # @param group_map [Hash{String, Array<String>}] map user keys to group names
  def initialize(group_map: {})
    @group_map = group_map
  end

  ##
  # @param user [::User]
  # @param groups [Array<String>, String]
  #
  # @return [void]
  def add(user:, groups:)
    @group_map[user.user_key] = fetch_groups(user: user) + Array(groups)
  end

  ##
  # @return [void]
  def clear
    @group_map = {}
  end

  ##
  # @param user [::User]
  #
  # @return [Array<String>]
  def fetch_groups(user:)
    @group_map.fetch(user.user_key) { [] }
  end

  ##
  # @return [Array<String>] a list of all known group names
  def role_names
    @group_map.values.flatten.uniq
  end
end

RSpec.configure do |config|
  config.before(:suite) { User.group_service = TestHydraGroupService.new }
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
  config.shared_context_metadata_behavior = :apply_to_host_groups

  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = 'spec/examples.txt'
  config.disable_monkey_patching!
  config.default_formatter = 'doc' if config.files_to_run.one?
  config.profile_examples = 10
  config.order = :random
  Kernel.srand config.seed
end
