# frozen_string_literal: true

module Hyrax
  class GwWorksController < ApplicationController
    include ::WorksControllerBehavior
    self.curation_concern_type = ::GwWork
    self.show_presenter = ::WorkShowPresenter
  end
end
