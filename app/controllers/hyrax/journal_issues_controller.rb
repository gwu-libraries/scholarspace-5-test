# frozen_string_literal: true

module Hyrax
  class JournalIssuesController < ApplicationController
    # Adds Hyrax behaviors to the controller.
    include ::WorksControllerBehavior
    self.curation_concern_type = ::JournalIssue

  end
end
