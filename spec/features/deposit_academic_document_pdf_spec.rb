require 'rails_helper'

RSpec.describe "Deposit a PDF AcademicDocument through dashboard" do

  let(:admin_set) { FactoryBot.create(:admin_set) }
  let(:admin_user) { FactoryBot.create(:admin) }
  let(:user) { FactoryBot.create(:user) }
  let(:pdf_path) { "#{Rails.root}/spec/fixtures/testing_pdf.pdf" }
  
  xit 'can deposit a pdf' do
    sign_in_user(admin_user)

    visit new_hyrax_academic_document_path

    fill_in('academic_document_title', with: "This is a PDF Academic Work")
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

    expect(page).to have_content("This is a PDF Academic Work")
  end

end