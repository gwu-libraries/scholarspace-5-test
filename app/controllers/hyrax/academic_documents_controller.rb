# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource AcademicDocument`
module Hyrax
  # Generated controller for AcademicDocument
  class AcademicDocumentsController < ApplicationController
    # Adds Hyrax behaviors to the controller.
    include ::WorksControllerBehavior
    self.curation_concern_type = ::AcademicDocument

  end
end
