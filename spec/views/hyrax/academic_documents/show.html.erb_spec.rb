# frozen_string_literal: true

RSpec.describe "work show view" do

  before do
    @user = FactoryBot.create(:user)
    @work = FactoryBot.valkyrie_create(
        :public_academic_document,
        title: "Comet in Moominland",
        abstract: "some fairy creatures meet a child from Sweden I think",
        access_right: "open",
        alternative_title: "mooninland",
        contributor: "Mystery",
        identifier: "867-5309",
        publisher: "Books Incorporated",
        language: "English",
        license: "public domain",
        rights_notes: "no rights reserved",
        source: "springwater",
        user: @user
      )
    
    Hyrax.index_adapter.save(resource: @work)

    visit "/concern/academic_documents/#{@work.id}"
  end

  it "shows a work" do

    require 'pry'; binding.pry

    expect(page).to have_selector 'h1', text: 'Comet in Moominland'
    expect(page).to have_selector 'dt', text: 'Abstract'
    expect(page).to have_selector 'dt', text: 'Access right'
    expect(page).to have_selector 'dt', text: 'Alternative title'
    expect(page).to have_selector 'dt', text: 'Contributor'
    expect(page).to have_selector 'dt', text: 'Identifier'
    expect(page).to have_selector 'dt', text: 'Publisher'
    expect(page).to have_selector 'dt', text: 'Language'
    expect(page).to have_selector 'dt', text: 'License'
    expect(page).to have_selector 'dt', text: 'Rights notes'
    expect(page).to have_selector 'dt', text: 'Source'
  end
end