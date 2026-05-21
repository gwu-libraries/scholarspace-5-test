# frozen_string_literal: true

module Hyrax
  class GwWorksController < ApplicationController
    include WorksControllerBehavior
    self.curation_concern_type = ::GwWork
  end
end
