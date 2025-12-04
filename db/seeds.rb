# frozen_string_literal: true

# Hyrax::TestDataSeeder.new.generate_seed_data if seed_release_testing

# ActiveFedora.fedora.connection.send(:init_base_path)
Hyrax::RequiredDataSeeder.new.generate_seed_data

admin_role = Role.find_or_create_by(name: Hyrax.config.admin_user_group_name)
admin_user =
  User.create(email: ENV['ADMIN_USER'], password: ENV['ADMIN_PASSWORD'])

admin_user.roles << admin_role

# puts "\n== Creating default collection types"
# Hyrax::CollectionType.find_or_create_default_collection_type
# Hyrax::CollectionType.find_or_create_admin_set_type

# puts "\n== Creating default admin set"
# admin_set_id =
#   Hyrax::AdminSetCreateService.find_or_create_default_admin_set.id.to_s

# puts "\n== Creating admin role"
# admin_role = Role.find_or_create_by(name: Hyrax.config.admin_user_group_name)

# puts "\n== Creating admin user"
# admin_user =
#   User.create(email: ENV["ADMIN_USER"], password: ENV["ADMIN_PASSWORD"])

# puts "\n== Adding admin role to admin user"
# admin_user.roles << admin_role

# # puts "\n== Saving admin user"
# # admin_user.save

# puts "\n== Creating public academic document"
# academic_document_1 =
#   FactoryBot.valkyrie_create(
#     :public_academic_document,
#     user: admin_user,
#     title: ["Beep beep"]
#   )

# Hyrax.persister.save(resouce: academic_document_1)
# #   # works, admin sets, collections (?) need to be valkyrie_created, everything else just create?
# #   # valkyrie_create(:hyrax_file_set)
# #   # valkyrie_create(:hyrax_admin_set)
# #   # valkyrie_create(:default_hyrax_admin_set)
# #   # let(:expired_lease) { valkyrie_create(:hyrax_lease, :expired) }
# #   # FactoryBot.valkyrie_create(:hyrax_file_metadata, :original_file, :with_file,

# #   #   let(:work) do
# #   #   FactoryBot.valkyrie_create(:hyrax_resource, lease: lease)
# #   # end

# #   # let(:file_metadata) { FactoryBot.valkyrie_create(:hyrax_file_metadata, :with_file) }
# #   # let(:file_set) { Hyrax.query_service.find_by(id: file_metadata.file_set_id) }

# #   # academic_document_admin_set =
# #   #   FactoryBot.valkyrie_create(
# #   #     :hyrax_admin_set,
# #   #     title: ["Academic Documents"],
# #   #     edit_users: [admin_user.user_key]
# #   #   )

# #   # permission_template =
# #   #   FactoryBot.create(
# #   #     :permission_template,
# #   #     source_id: academic_document_admin_set.id
# #   #   )

# #   # FactoryBot.create(
# #   #   :permission_template_access,
# #   #   :deposit,
# #   #   permission_template: permission_template,
# #   #   agent_type: "user",
# #   #   agent_id: admin_user.user_key
# #   # )
