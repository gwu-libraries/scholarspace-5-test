FactoryBot.define do
  factory :bulkrax_importer, class: "Bulkrax::Importer" do

    name {"Test importer"}
    admin_set_id { FactoryBot.create(:admin_set).id }
    user { User.find_by(email: "admin@example.com") }
    frequency { "PT0S"}
    parser_klass {"Bulkrax::CsvParser"}
    # default values from the Importer form
    parser_fields do
      {"visibility"=>"open", "rights_statement"=>"", "override_rights_statement"=>"0", "file_style"=>"Upload a File", "entry_statuses"=>[""], "import_file_path" => "spec/fixtures/testing_bulkrax_import.zip"}
    end
  end
end
