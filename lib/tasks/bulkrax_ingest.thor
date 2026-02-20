require 'thor'
require 'fileutils'

class BulkraxIngestTask < Thor
  # Pass the name of a file (expects .zip) for importing
  desc "bulk_import FILE", "runs a Bulkrax importer"
  # Include the name of an admin set (if other than default)
  option :admin_set, required: false, type: :string, aliases: :a
  # Provide the ID (email address) of a user; otherwise, it will be extracted from the CSV's depositor field
  option :user, required: false, type: :string, aliases: :u
  def bulk_import(file)
      user = options.fetch(:user) || get_depositor_from_csv(file)
      # Use the default Admin Set if none provided
      admin_set_id = options[:admin_set].nil? ? Hyrax::AdminSetCreateService.find_or_create_default_admin_set.id : get_admin_sets(user, options[:admin_set])

      parser_fields = {"visibility"=>"open",
                        "rights_statement"=>"",
                        "override_rights_statement"=>"0",
                        "file_style"=>"Upload a File",
                        "entry_statuses"=>[""],
                        "import_file_path" => file
      }
      importer_params = {name: "rake-import",
        user_id: user.id,
        parser_fields: parser_fields,
        frequency: "PT0S",
        parser_klass: "Bulkrax::CsvParser",
        admin_set_id: admin_set_id
      }
      @importer = Bulkrax::Importer.new(importer_params)
      @importer.field_mapping = Bulkrax.field_mappings["Bulkrax::CsvParser"]
      @importer.save
      # TO DO: confirm that this result is returned on success
      enqueue_result = Bulkrax::ImporterJob.send(@importer.parser.perform_method, @importer.id)
      if not enqueue_result
        raise "Importer job could not be enqueued!"
      end
      # Update zip with importer ID and move to "in process" location
      update_file(file)
    end

    desc "get_importer_status", "updates the status of pending Bulkrax entries"
    # If --next, task will re-schedule itself upon completion
    option :next, required: false, type: :boolean, aliases: :n
    def get_importer_status
      #Bulkrax::CsvEntry.find(268).current_status.error_backtrace
    end

end

  def update_file(file)
    # Check permissions when running as Docker command
    FileUtils.mkdir_p("tmp/imports/pending")
  end

  def get_admin_sets(user, admin_set_title)
    # Following Bulkrax logic
    # Identify the user's abilities
    ability = ::Ability.new(user)
    # Find the admin sets for which that user has deposit permissions
    admin_sets = Hyrax::Collections::PermissionsService.source_ids_for_deposit(ability: ability, source_type: "admin_set").map do |admin_set_id|
      [Bulkrax.object_factory.find_or_nil(admin_set_id)&.title&.first || admin_set_id, admin_set_id]
    end.select do |admin_set|
      admin_set[0] == admin_set_title
    end
    if not admin_sets.blank?
      return admin_sets.first[1] # Return the ID of the matching AdminSet
    end
    raise "No matching admin sets found to which the user has deposit permissions!"
  end

  def get_depositor_from_csv(file)
    # Find depositor in CSV file
    Zip::File.open(file) do |zip_file|
      # Assume a zipped import has a single CSV at the top level
      entry = zip_file.glob("*.csv").first
      csv = CSV.parse(entry.get_input_stream.read, headers: true)
      # Assume the relevant user is the depositor for the first row.
      user_email = csv[0]["depositor"]
      user = User.find_by(email: user_email)
      if not user
        raise "No user matching depositor value #{user_email} found in the database!"
      end
      user
    end
  end
