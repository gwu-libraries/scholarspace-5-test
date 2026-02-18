require 'rake'

namespace :gwss do
  desc "Import one batch of works and files via Bulkrax"
  task :run_import => :environment do
    # TO DO: accept path to zip file from command line
    # TO DO: accept AdminSet name from command line and query for ID
    # TO DO: accept user from command line
    parser_fields = {"visibility"=>"open",
                      "rights_statement"=>"",
                      "override_rights_statement"=>"0",
                      "file_style"=>"Upload a File",
                      "entry_statuses"=>[""],
                      "import_file_path" => "spec/fixtures/testing_bulkrax_import.zip"
    }
    importer_params = {name: "rake-import",
      user_id: User.find_by(email: "admin@example.com").id,
      parser_fields: parser_fields,
      frequency: "PT0S",
      parser_klass: "Bulkrax::CsvParser",
      admin_set_id: "9851fdc7-174e-44e9-924e-2c079e9078f9"
    }
    @importer = Bulkrax::Importer.new(importer_params)
    @importer.field_mapping = Bulkrax.field_mappings["Bulkrax::CsvParser"]
    #importer.parser_fields['update_files'] = true
    @importer.save
    # Reference for deactivating listener at the conclusion of the upload
    @listener = activate_listener
    Bulkrax::ImporterJob.send(@importer.parser.perform_method, @importer.id)

  end
end


def activate_listener
  bulkrax_listener = BulkraxListener.new
  publisher = Hyrax::Publisher.instance
  publisher.subscribe(bulkrax_listener)
  return bulkrax_listener
end
