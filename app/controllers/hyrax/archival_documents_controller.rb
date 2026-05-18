# frozen_string_literal: true

# Generated via
#  `rails generate hyrax:work_resource ArchivalDocument`
module Hyrax
  # Generated controller for ArchivalDocument
  class ArchivalDocumentsController < ApplicationController
    include Hyrax::ScholarspaceWorksControllerBehavior
    self.curation_concern_type = ::ArchivalDocument
  end
end
