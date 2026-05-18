# frozen_string_literal: true

# Concern that consolidates indexing setup for searchable works with OCR, VTT, and full-text support
module SearchableWorkIndexable
  extend ActiveSupport::Concern

  included do
    include OcrTextIndexable
    include VttIndexable
    include FullTextIndexable
  end
end
