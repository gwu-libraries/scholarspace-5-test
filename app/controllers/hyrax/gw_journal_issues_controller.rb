# frozen_string_literal: true

module Hyrax
  class GwJournalIssuesController < ApplicationController
    include ::WorksControllerBehavior
    self.curation_concern_type = ::GwJournalIssue
    self.show_presenter = ::WorkShowPresenter
  end
end
