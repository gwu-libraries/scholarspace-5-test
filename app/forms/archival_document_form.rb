# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource ArchivalDocument`
#
# @see https://github.com/samvera/hyrax/wiki/Hyrax-Valkyrie-Usage-Guide#forms
# @see https://github.com/samvera/valkyrie/wiki/ChangeSets-and-Dirty-Tracking
class ArchivalDocumentForm < Hyrax::Forms::PcdmObjectForm(ArchivalDocument)
  include Hyrax::FormFields(:basic_metadata)
  include Hyrax::FormFields(:archival_document)

  # Define custom form fields using the Valkyrie::ChangeSet interface
  #
  # property :my_custom_form_field

  # if you want a field in the form, but it doesn't have a directly corresponding
  # model attribute, make it virtual
  #
  # property :user_input_not_destined_for_the_model, virtual: true
end
