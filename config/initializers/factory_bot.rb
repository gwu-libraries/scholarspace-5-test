# frozen_string_literal: true

# Allows using factories defined in Hyrax gem - maybe a cleaner way to do this is available,
# but at the moment this works for first loading factory definitions from Hyrax, followed by
# factory definitions from ScholarSpace

FactoryBot.definition_file_paths = [
  File.expand_path(
    "#{Gem.loaded_specs['hyrax'].full_gem_path}/lib/hyrax/specs/shared_specs/factories",
    __FILE__
  ),
  Rails.root.join('spec', 'factories')
]

# Loads additional factory_bot strategies from Hyrax

Dir[
  "#{Gem.loaded_specs['hyrax'].full_gem_path}/lib/hyrax/specs/shared_specs/factories/strategies/*.rb"
].each { |f| require f }

FactoryBot.register_strategy(:valkyrie_create, ValkyrieCreateStrategy)
FactoryBot.register_strategy(:json, JsonStrategy)
