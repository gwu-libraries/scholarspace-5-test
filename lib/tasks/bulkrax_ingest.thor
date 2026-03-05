require 'thor'
require 'fileutils'
require 'pry'

class BulkraxIngestTask < Thor
  # Pass the name of a file (expects .zip) for importing
  desc "bulk_import FILE", "runs a Bulkrax importer"
  # Include the name of an admin set (if other than default)
  option :admin_set, required: false, type: :string, aliases: :a
  # Provide the ID (email address) of a user; otherwise, it will be extracted from the CSV's depositor field
  option :user, required: false, type: :string, aliases: :u
  def bulk_import(file)
      user_email = options.fetch(:user, get_depositor_from_csv(file))
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

    desc "update_importer_status", "updates the status of pending Bulkrax entries"
    # TO DO: handle failures not associated with specific entries
    option :import_id, required: false, type: :string, aliases: :i
    def update_importer_status
      # Glob files in pending directory
      pending = Dir.glob("tmp/imports/pending/*")
      # For each, retrieve the importer by its id, get the last run, and check the status
      import_id = options.fetch(:import_id, nil)
      if import_id
        # If import_id provided, use only files matching that ID
        pending = pending.select { |f| f.ends_with?("_#{import_id}") }
      end
      pending.each do |file|
        # Extract the import ID from the file name
        importer = get_importer(file)
        # Skip any still pending
        next if (!importer) || (importer.last_run.statuses.select { |s| s.status_message.include? "Complete" }.empty?)
        # If complete with failures inspect the failed entries
        status_rows = []
        importer.failed_statuses.each do |status|
          # If the failure is due to a failed entry, get its identifier
          entry_id = status.statusable_type == "Bulkrax::Entry" ? status.statusable_id : nil
          if entry_id
            # retrieve the entry associated with this status
            entry = importer.entries.find { |entry| entry.id = entry_id }
            row = entry.raw_metadata
            # Update original metadata with errors
            [:error_class, :error_message, :error_backtrace].each do |key|
              row[key] = status[key]
            end
            # Convert backtrace from array to string
            row[:error_backtrace] = row[:error_backtrace].join("\n")
            status_rows << row
          end
        end
        update_files(status_rows, importer, file)
      end
    end
end

  def update_pending(importer)
    # Check permissions when running as Docker command
    FileUtils.mkdir_p("tmp/imports/pending")
    # path to unzipped CSV in tmp/imports always starts with the Importer.id
    # The path may not exist yet at time of execution, so we just create an empty file in the pending directory to record the ID
    FileUtils.touch("tmp/imports/pending/import_#{importer.id}")
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

  def get_importer(file_name)
    m = /import_(\d+)/.match(file_name)
    import_id = m[1]
    return if not import_id
    # Retrieve importer with this ID
    Bulkrax::Importer.find(import_id.to_i)
  rescue
    warn "No importer found for import ID #{import_id} from file #{file_name}. Perhaps it was deleted?"
  end

  def update_files(rows, importer, pending_file)
    csv_file = Dir.glob("tmp/imports/import_#{importer.path_string}/*.csv").first
    csv_name = File.basename(csv_file, ".*")
    if not rows.empty?
      # Create new CSV in processed folder with the same name as the original plus an _errors suffix
      FileUtils.mkdir_p("tmp/imports/processed")
      CSV.open("tmp/imports/processed/#{csv_name}_errors_from_importer_#{importer.id}.csv", "w") do |csv|
        headers = rows.flat_map(&:keys).uniq
        csv << headers
        rows.each { |row| csv << row.values_at(*headers) }
      end
    else
      # Create symlink to original in processed folder
      File.symlink(csv_file, "tmp/imports/processed/#{csv_name}.csv")
    end
    # Delete file in pending folder
    File.delete(pending_file)
  end
