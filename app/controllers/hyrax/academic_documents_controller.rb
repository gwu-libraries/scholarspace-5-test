# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource AcademicDocument`
module Hyrax
  # Generated controller for AcademicDocument
  class AcademicDocumentsController < ApplicationController
    include Hyrax::ScholarspaceWorksControllerBehavior
    self.curation_concern_type = ::AcademicDocument
  end
end
