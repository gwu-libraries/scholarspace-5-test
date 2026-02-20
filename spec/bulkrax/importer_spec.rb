require 'rails_helper'
require 'pry'

RSpec.describe "Import files and works with Bulkrax" do

  before :all do
    @importer = FactoryBot.build(:bulkrax_importer)
    field_mapping_key = "Bulkrax::CsvParser"
    @importer.field_mapping = Bulkrax.field_mappings[field_mapping_key]
    @importer.parser_fields['update_files'] = true
    @importer.save
    #binding.pry
    perform_enqueued_jobs do
      Bulkrax::ImporterJob.send(@importer.parser.perform_method, @importer.id)
    end
  end
  describe "Imported works and files" do
    xit "Has the correct visibility" do
      #binding.pry
      puts @importer.current_run.inspect
    end
  end

end

=begin
#<ActionController::Parameters {"authenticity_token"=>"kf8U83C-WgXomskt8sB4fDZJ9aXWm5hMtWgkuUcuKNZT-Y_O_tRrF02xkRL8MXd58G5hQmaixIuytJI0BrGIvg", "importer"=>{"name"=>"test-pry", "admin_set_id"=>"9851fdc7-174e-44e9-924e-2c079e9078f9", "user_id"=>"1", "frequency"=>"PT0S", "limit"=>"", "parser_klass"=>"Bulkrax::CsvParser", "parser_fields"=>{"visibility"=>"open", "rights_statement"=>"", "override_rights_statement"=>"0", "file_style"=>"Upload a File", "import_file_path"=>"", "entry_statuses"=>[""]}}, "uploaded_files"=>["270"], "commit"=>"Create and Import", "locale"=>"en", "controller"=>"bulkrax/importers", "action"=>"create"} permitted: false>
=end
# Get a reference to the uploaded zipfile
# uploads = Hyrax::UploadedFile.find(params[:uploaded_files]) if params[:uploaded_files].present?
=begin
[#<Hyrax::UploadedFile:0x00007fb8b21f0780
  id: 270,
  file: "work_open_fileset_open.zip",
  user_id: 1,
  file_set_uri: nil,
  created_at: "2026-02-10 16:28:33.979125000 +0000",
  updated_at: "2026-02-10 16:28:34.204420000 +0000",
  filename: nil>]
=end
#  @importer = Importer.new(importer_params)
=begin
#<Bulkrax::Importer:0x00007fb8b22c9260
id: nil,
name: "test-pry",
admin_set_id: "9851fdc7-174e-44e9-924e-2c079e9078f9",
user_id: 1,
frequency: "PT0S",
parser_klass: "Bulkrax::CsvParser",
limit: nil,
parser_fields:
 {"visibility"=>"open", "rights_statement"=>"", "override_rights_statement"=>"0", "file_style"=>"Upload a File", "import_file_path"=>"", "entry_statuses"=>[""]},
field_mapping: nil,
created_at: nil,
updated_at: nil,
validate_only: nil,
last_error_at: nil,
last_succeeded_at: nil,
status_message: "Pending",
last_imported_at: nil,
next_import_at: nil,
error_class: nil>
=end
# field_mapping_params
# @importer.parser_fields['update_files'] = true if params[:commit] == 'Create and Import'
# @importer.save
# files_for_import(nil, nil, uploads) # to implement --> pass first param, not last, as ref to file on disk??
# Bulkrax::ImporterJob.send(@importer.parser.perform_method, @importer.id)
=begin
#<Bulkrax::ImporterJob:0x00007fb8cfdf7458
 @_halted_callback_hook_called=nil,
 @arguments=[62],
 @exception_executions={},
 @executions=0,
 @job_id="7dd94e62-cffb-4bb7-b1b0-3851bd78cfcc",
 @priority=nil,
 @provider_job_id="aa08b703521981e809d54f9f",
 @queue_name="ingest",
 @scheduled_at=nil,
 @successfully_enqueued=true,
 @timezone="UTC">
=end
