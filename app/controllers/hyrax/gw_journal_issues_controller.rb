# frozen_string_literal: true

module Hyrax
  class GwJournalIssuesController < ApplicationController
    include Hyrax::ScholarspaceWorksControllerBehavior
    self.curation_concern_type = ::GwJournalIssue
  end
end
