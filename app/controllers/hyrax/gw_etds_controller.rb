# frozen_string_literal: true

module Hyrax
  class GwEtdsController < ApplicationController
    include WorksControllerBehavior
    self.curation_concern_type = ::GwEtd
  end
end
