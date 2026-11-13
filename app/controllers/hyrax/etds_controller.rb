# frozen_string_literal: true

module Hyrax
  class EtdsController < ApplicationController
    # Adds Hyrax behaviors to the controller.
    include ::WorksControllerBehavior
    self.curation_concern_type = ::ETD

  end
end
