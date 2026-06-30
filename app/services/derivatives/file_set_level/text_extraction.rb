# frozen_string_literal: true

module Derivatives
  module FileSetLevel
    module TextExtraction
      def self.from_pdf(work)
        FromPdf.new(work)
      end

      def self.from_images
        FromImages
      end
    end
  end
end
