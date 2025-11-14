require 'rails_helper'

RSpec.describe "Deposit a PDF through dashboard" do

  let(:admin_set) { FactoryBot.create(:admin_set) }
  let(:admin_user) { FactoryBot.create(:admin) }
  let(:user) { FactoryBot.create(:user) }
  let(:pdf_path) { "#{Rails.root}/spec/fixtures/testing_pdf.pdf" }
  let(:solr) { Blacklight.default_index.connection }

  xit 'cannot deposit as a non-admin user' do

    sign_in_user(user)

    visit new_hyrax_academic_document_path

    expect(current_path).to eq(root_path)

  end

  it 'can deposit a pdf' do
    
    sign_in_user(admin_user)

    visit new_hyrax_academic_document_path

    fill_in('academic_document_title', with: "This is a PDF ETD")
    select('Article', from: 'academic_document_resource_type')
    fill_in('academic_document_creator', with: "Sandwich P. Kitty")
    select('Attribution 4.0 International', from: 'academic_document_license')
    select('In Copyright', from: 'academic_document_rights_statement')

    click_link "Files"

    within "#add-files" do
      attach_file("files[]", pdf_path, visible: false)
    end
    
    find('body').click
    choose('academic_document_visibility_open')
    check('agreement')

    click_on('Save')

    expect(page).to have_content("Your files are being processed by ScholarSpace in the background.")

  end

end