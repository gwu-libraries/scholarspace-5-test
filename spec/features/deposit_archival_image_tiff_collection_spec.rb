require 'rails_helper'

RSpec.describe "Deposit a set of TIFF images through dashboard" do

  let(:admin_set) { FactoryBot.create(:admin_set) }
  let(:admin_user) { FactoryBot.create(:admin) }
  let(:user) { FactoryBot.create(:user) }
  let(:tiff1_path) { "#{Rails.root}/spec/fixtures/tiff_images/test_tiff_01.tiff" }
  let(:tiff2_path) { "#{Rails.root}/spec/fixtures/tiff_images/test_tiff_02.tiff" }
  let(:tiff3_path) { "#{Rails.root}/spec/fixtures/tiff_images/test_tiff_03.tiff" }
  
  it 'can deposit a set of tiff images' do
    sign_in_user(admin_user)

    visit new_hyrax_archival_image_path

    fill_in('archival_image_title', with: "This is a TIFF Image Set")
    fill_in('archival_image_creator', with: "Sandwich P. Kitty")
    select('Attribution 4.0 International', from: 'archival_image_license')
    select('In Copyright', from: 'archival_image_rights_statement')

    click_link "Files"

    within "#add-files" do
      attach_file("files[]", [tiff1_path, tiff2_path], visible: false)
    end
    
    find('body').click
    choose('archival_image_visibility_open')
    check('agreement')

    click_on('Save')

    expect(page).to have_content("This is a TIFF Image Set")
  end

end