if Rails.env == "production"
  puts "Seeding data for release testing is not for use in production!"
  exit
end

include FactoryBot::Syntax::Methods

if ENV["SEED_REQUIRED_RECORDS"]
  UserSeeder.generate_required_seeds
  # Generates admin@example.com with admin_password

  CollectionTypeSeeder.generate_required_seeds
  # Generates admin set collection type and default user collection type

  AdminSetSeeder.generate_required_seeds
  # Generates default admin set
end

if ENV["SEED_TESTING_RECORDS"]
  # UserSeeder.generate_test_seeds
  # Generates
  #  - basic_user@example.com:password
  #  - another_user@example.com:password
end
