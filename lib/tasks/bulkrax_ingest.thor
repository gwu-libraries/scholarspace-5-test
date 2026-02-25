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
      user_email = options.fetch(:user) || get_depositor_from_csv(file)
      user = get_user(user_email)
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
      importer = Bulkrax::Importer.new(importer_params)
      importer.field_mapping = Bulkrax.field_mappings["Bulkrax::CsvParser"]
      importer.save
      # TO DO: confirm that this result is returned on success
      enqueue_result = Bulkrax::ImporterJob.send(importer.parser.perform_method, importer.id)
      if not enqueue_result
        raise "Importer job could not be enqueued!"
      end
      update_pending(importer)
    end

    desc "get_importer_status", "updates the status of pending Bulkrax entries"
    # If --next, task will re-schedule itself upon completion
    option :import_id, required: false, type: :string, aliases: :i
    def get_importer_status
      # Glob files in pending directory
      pending = Dir.glob("tmp/imports/pending/*.csv")
      # For each, retrieve the importer by its id, get the last run, and check the status
      if import_id
        pending = pending.select { |f| f.ends_with?("_#{import_id}.csv") }
      end
      pending.each do |file|
        m = /.+_(\d+)\.csv/.match(file)
        import_id = m[1]
        next if not import_id
        csv_file = File.readlink(file)
        importer = Bulkrax::Importer.find(import_id.to_i)
        # If complete with failures inspect the failed entries
        status_rows = []
        importer.failed_statuses.each do |status|
          # If the failure is due to a failed entry, get its identifier
          entry_id = status.statusable_id if status.statusable_type == "Bulkrax::Entry" else nil
          if entry_id
            # retrieve the entry associated with this status
            entry = importer.entries.find { |entry| entry.id = entry_id }
            row = entry.raw_metadata
            # Update original metadata with errors
            [:error_class, :error_message, :error_backtrace].each do |key|
              row[key] = status[key]
            end
            # Convert backtrace from array to string
            row[:error_backtrace] = row[:backtrace].join("\n")
            status_rows << row
          end
        end
        if not status_rows.empty?
          # Create new CSV in processed folder with the same name as the original plus an _errors suffix
          FileUtils.mkdir_p("tmp/imports/processed")
          csv_name = File.basename(csv_file, ".*")
          CSV.open("tmp/imports/processed/#[csv_name}_errors.csv", "w") do |csv|
            headers = status_rows.flat_map(&:keys).uniq
            csv << headers
            status_rows.each { |row| csv << row.values_at(*headers) }
          end
        else
          # Create symlink to original in processed folder
          File.symlink(csv_file, "tmp/imports/processed/#{csv_name}.csv")
        end
        # Delete symlink in pending folder
          File.delete(file)
      end
    end
end

  def update_pending(importer)
    # Check permissions when running as Docker command
    FileUtils.mkdir_p("tmp/imports/pending")
    # path to unzipped CSV in tmp/imports
    # per https://github.com/samvera/bulkrax/blob/33f3285b0ad9fc0d85fb633882798033ef496d0f/app/models/bulkrax/importer.rb#L258
    csv_path = Dir.glob("tmp/imports/import_#{importer.path_string}/*.csv").first
    # Create a link in the pending directory (to avoid duplicating the data on disk)
    File.symlink(csv_path, "tmp/imports/pending/import_#{importer.id}.csv")
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


  def get_user(user_email)
    user = User.find_by(email: user_email)
    if not user
      raise "No user matching depositor value #{user_email} found in the database!"
    end
    user
  end

  def get_depositor_from_csv(file)
    # Find depositor in CSV file
    Zip::File.open(file) do |zip_file|
      # Assume a zipped import has a single CSV at the top level
      entry = zip_file.glob("*.csv").first
      csv = CSV.parse(entry.get_input_stream.read, headers: true)
      # Assume the relevant user is the depositor for the first row.
      user_email = csv[0]["depositor"]
      user_email
    end
  end
