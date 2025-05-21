# frozen_string_literal: true

wipe_data = ActiveModel::Type::Boolean.new.cast(ENV.fetch('WIPE_DATA', false))
seed_release_testing = ActiveModel::Type::Boolean.new.cast(ENV.fetch('SEED_RELEASE_TESTING', false))
seed_scholarspace = ActiveModel::Type::Boolean.new.cast(ENV.fetch('SEED_SCHOLARSPACE', false))

unless wipe_data || seed_release_testing
  Rails.logger.debug 'NAME'
  Rails.logger.debug '     rails db:seed (Hyrax)'
  Rails.logger.debug
  Rails.logger.debug 'SYNOPSIS'
  Rails.logger.debug '     bundle exec rails db:seed [WIPE_DATA=true|false] [SEED_RELEASE_TESTING=true|false] [SEED_SCHOLARSPACE=true|false]'
  Rails.logger.debug
  Rails.logger.debug 'DESCRIPTION'
  Rails.logger.debug '     Hyrax defined db:seed provides a means to clear repository metadata from the datastore (e.g. Fedora, Postgres) and from Solr.'
  Rails.logger.debug '     Seeds can be run to pre-populate metadata to help with release testing and local development testing.'
  Rails.logger.debug
  Rails.logger.debug '     NOTE: Options can be passed in with the command on the command line or set as ENV variables.'
  Rails.logger.debug
  Rails.logger.debug '     The options are as follows:'
  Rails.logger.debug
  Rails.logger.debug '     WIPE_DATA'
  Rails.logger.debug '             USE WITH CAUTION - Deleted data cannot be recovered.'
  Rails.logger.debug
  Rails.logger.debug '             When true, it will clear all repository metadata from the datastore (e.g. Fedora, Postgres) and from Solr.  It also'
  Rails.logger.debug '             clears data from the application database that are tightly coupled to repository metadata.  See Hyrax::DataMaintenance'
  Rails.logger.debug '             for more information on what data will be destroyed by this process.'
  Rails.logger.debug
  Rails.logger.debug '             The wipe_data process will also restore required repository metadata including collection types and the default admin'
  Rails.logger.debug '             set.  See Hyrax::RequiredDataSeeder for more information on what data will be created by this process.'
  Rails.logger.debug
  Rails.logger.debug '     SEED_RELEASE_TESTING'
  Rails.logger.debug '             When true, it will run the set of seeds for release testing creating a repository metadata and support data, including'
  Rails.logger.debug '             test users, collection types, collections, and works with and without files.  See Hyrax::TestDataSeeder for more information'
  Rails.logger.debug '             on what data will be created by this process.'
  Rails.logger.debug
  Rails.logger.debug '     SEED_SCHOLARSPACE'
  Rails.logger.debug '             When true, it will run a minimal set of seeds for scholarspace test app, including required collection types, default admin set,'
  Rails.logger.debug '             and test users.'
  Rails.logger.debug
  Rails.logger.debug '     ALLOW_RELEASE_SEEDING_IN_PRODUCTION'
  Rails.logger.debug '             USE WITH EXTERME CAUTION WHEN USED IN PRODUCTION - Deleted data cannot be recovered.  Attempts are made to not overwrite'
  Rails.logger.debug '             existing data, but use in production is not recommended.'
  Rails.logger.debug
  Rails.logger.debug '             If this is NOT true, the process will abort when Rails environment is production.'
  Rails.logger.debug
end

allow_release_seeding_in_production = ActiveModel::Type::Boolean.new.cast(ENV.fetch(
                                                                            'ALLOW_RELEASE_SEEDING_IN_PRODUCTION', false
                                                                          ))

if Rails.env.production? && !allow_release_seeding_in_production
  Rails.logger.debug 'Seeding data for release testing is not for use in production!'
  exit
end

if wipe_data
  Rails.logger.debug '####################################################################################'
  Rails.logger.debug
  Rails.logger.debug 'WARNING: You are about to clear all repository metadata from the datastore and solr.'
  Rails.logger.debug 'Are you sure? [YES|n]'
  answer = $stdin.gets.chomp
  unless answer == 'YES'
    Rails.logger.debug '   Aborting!'
    Rails.logger.debug '####################################################################################'
    exit
  end

  Hyrax::DataMaintenance.new.destroy_repository_metadata_and_related_data
  Hyrax::RequiredDataSeeder.new.generate_seed_data
end

if seed_scholarspace
  Rails.logger.debug 'Seeding Scholarspace ...'

  Hyrax::RequiredDataSeeder.new.generate_seed_data
  Hyrax::TestDataSeeders::UserSeeder.generate_seeds
end

Hyrax::TestDataSeeder.new.generate_seed_data if seed_release_testing
