require 'thor'
require 'fileutils'
require 'sidekiq/api'


class BulkraxIngestTask < Thor
  # Pass the name of a file or glob pattern (expects .zip) for importing
  desc "bulk_import FILE || PATTERN", "runs a Bulkrax importer"
  # Include the name of an admin set (if other than default)
  option :admin_set, required: false, type: :string, aliases: :a
  # Provide the ID (email address) of a user; otherwise, it will be extracted from the CSV's depositor field
  option :user, required: true, type: :string, aliases: :u
  def bulk_import(file)

    # Capture UUID strings from import filenames
    uuid_re =  /([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/

    files = File.file?(file) ? [file] : Dir.glob(file)
    # find the first file in the list that has no importer with a name matching the ID its name
    importers = Bulkrax::Importer.all.map { |importer| importer.name }
    to_import = files.map do |file|
      batch_id = uuid_re.match(file)&.captures[0] # Expect UUID in filename
      [batch_id, file]
    end.select do |(batch_id, file)|
      batch_id && !importers.include?(batch_id)
    end.first
    if to_import.nil?
      raise "No files to import found or all files have been imported. Importer files should have a UUID in the filename for matching with Bulkrax importers."
    end
    user_email = options.fetch(:user)
    user = get_user(user_email)
    # Use the default Admin Set if none provided
    admin_set_id = options[:admin_set].nil? ? Hyrax::AdminSetCreateService.find_or_create_default_admin_set.id : get_admin_sets(user, options[:admin_set])

    parser_fields = {"visibility"=>"open",
                        "rights_statement"=>"",
                        "override_rights_statement"=>"0",
                        "file_style"=>"Upload a File",
                        "entry_statuses"=>[""],
                        "import_file_path" => to_import[1]
    }
    importer_params = {name: "#{to_import[0]}",
        user_id: user.id,
        parser_fields: parser_fields,
        frequency: "PT0S",
        parser_klass: "Bulkrax::CsvParser",
        admin_set_id: admin_set_id
    }
    importer = Bulkrax::Importer.new(importer_params)
    importer.field_mapping = Bulkrax.field_mappings["Bulkrax::CsvParser"]
    importer.save
    Bulkrax::ImporterJob.send(importer.parser.perform_method, importer.id)
  end

  desc "generate_migration_report REPORT_JSONL", "generates a report from all Bulkrax importers matching imported items in REPORT_JSONL"
  def generate_migration_report(report_json)
    report_data = Hash.new { |h, k| h[k] = [] } # initialize to hash of arrays
    File::open(report_json) do |f|
      f.each_line do |line|
        line_json = JSON.parse(line)
        report_data[line_json["batch"]] << line_json # Store each row under its batch ID
      end
    end
    # Build hash of entries to importer data
    importer_entry_data = Hash.new { |h, k| h[k] = {} } # initialize to hash of hashes
    # For information about importers that failed before processing entries
    importers_failed = {}
    # Extract batch IDs from this report
    batch_ids = report_data.keys
    Bulkrax::Importer.all.each do |importer|
      next unless batch_ids.include? importer.name
      importer_id = importer.id
      importer_name = importer.name # Assumes Importer.name matches the ID of an imported batch
      zip_file = importer.original_file
      # Extract any error messages for entries in this batch
      status_hash = importer.failed_statuses.inject({}) do |h, status|
        entry_id = status.statusable_type == "Bulkrax::Entry" ? status.statusable_id : nil
        if entry_id
          h[entry_id] =  status.slice(:error_class, :error_message, :error_backtrace)
        end
      end
      importer.entries.each do |entry|
        entry_data = { importer_id: importer_id, zip_file: zip_file, import_status: importer.status_message, status_message: entry[:status_message], entry_id: entry.id, batch_id: importer_name}
        entry_data.merge!(status_hash.fetch(entry.id, {}))
        importer_entry_data[entry["identifier"]][importer_name] = entry_data
      end
      if importer.entries.empty?
        importers_failed[importer_name] = {importer_id: importer_id, importer_status: importer.status, importer_error_class: importer.error_class}
      end
    end
    # Update original report
    report_with_imports = []
    report_data.each do |batch, rows|
        rows.each do |row|
          # skip files
          next unless row.has_key? "row"
          # TO DO: log those not found?
          entry = importer_entry_data.fetch(row["row"]["bulkrax_identifier"], nil)
          next unless !entry.nil?
          entry_this_batch = entry.fetch(batch, nil)
          next unless !entry_this_batch.nil?
          updated_row = row["row"].merge(entry_this_batch)
          if updated_row.fetch(:error_backtrace, nil)
            updated_row[:error_backtrace] = updated_row[:error_backtrace].slice(0, 100).join("\n")
          end
          report_with_imports << {"batch": batch, "row": updated_row}
        end
    end
    if !importers_failed.empty?
      importers_failed_file = report_json.sub('.jsonl', '_failed_importers.json')
      puts "Saving importer metadata for failed importers to #{importers_failed_file}"
      File::open(importers_failed_file, 'w') do |f|
        f.write(importers_failed.to_json)
      end
    end
    if report_with_imports.empty?
      puts "No entries found matching any works or files in the report."
      return
    end
    updated_report_name = report_json.sub('.jsonl', '_with_import_status.jsonl')
    puts "Saving import status and errors to #{updated_report_name}."
    File::open(updated_report_name, "w") do |f|
      report_with_imports.each do |row|
          line_json = JSON.dump(row)
          f.write("#{line_json}\n")
      end
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

  def update_files(failure_report, failure_rows, importer, pending_file)
    csv_file = Dir.glob("tmp/imports/import_#{importer.path_string}/*.csv").first
    csv_name = File.basename(csv_file, ".*")
    if not failure_rows.empty?
      # Create new CSV in processed folder with the same name as the original plus an _errors suffix
      FileUtils.mkdir_p("tmp/imports/processed")
      CSV.open("tmp/imports/processed/#{csv_name}_errors_from_importer_#{importer.id}.csv", "w") do |csv|
        headers = failure_rows.flat_map(&:keys).uniq
        csv << headers
        failure_rows.each { |row| csv << row.values_at(*headers) }
      end
    elsif not failure_report.empty?
      # Save import failure to JSON
      File.open("tmp/imports/processed/#{csv_name}.failure.json", "w") { |f| f.puts failure_report.to_json }
    else
      # On success, create symlink to original in processed folder
      File.symlink(csv_file, "tmp/imports/processed/#{csv_name}.csv")
    end
    # Delete file in pending folder
    File.delete(pending_file)
  end
