require 'rails_helper'

RSpec.describe 'Sidekiq Dashboard Access' do
  it 'loads sidekiq dashboard for a logged in admin user' do
    admin_user = User.create(email: 'admin@example.com', password: 'password')
    admin_user.roles << Role.find_or_create_by(name: 'admin')

    sign_in_user(admin_user)

    visit('/sidekiq')

    expect(current_path).to eq('/sidekiq')
  end

  it 'redirects users to sign-in page if not logged in as admin' do
    visit('/sidekiq')

    expect(current_path).to eq('/users/sign_in')
  end

  it 'redirects to a 404 page if visited by logged in non-admin user' do
    non_admin_user = User.create(email: 'not_an_admin@example.com', password: 'password')

    sign_in_user(non_admin_user)

    visit('/sidekiq')

    expect(page).to have_content('404: Page not found')
  end
end
