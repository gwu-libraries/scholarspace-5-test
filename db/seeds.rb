UserSeeder.generate_required_seeds
# Generates admin user, configured in .env

CollectionTypeSeeder.generate_required_seeds
# Generates admin set collection type and default user collection type

AdminSetSeeder.generate_required_seeds
# Generates default admin set

if ENV["SEED_TESTING_RECORDS"]
  if Rails.env == "production"
    puts "Seeding data for testing is not for use in production!"
    exit
  end
  # UserSeeder.generate_test_seeds
  # Generates
  #  - basic_user@example.com:password
  #  - another_user@example.com:password
end
